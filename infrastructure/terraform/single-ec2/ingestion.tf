# ---------------------------------------------------------------------------
# Data Ingestion — one-time ARM/Graviton EC2 via ASG (scale 0 → 1 → 0)
#
# Mirrors the demo pattern: boots, downloads pipeline code + CSV from S3,
# installs dependencies, runs ingestion against the app instance's
# OpenSearch container, then self-terminates (scales ASG back to 0).
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# CloudWatch Log Group
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ingest" {
  name              = "/ec2/${local.name_prefix}/ingest"
  retention_in_days = 7

  tags = { Name = "${local.name_prefix}-ingest-logs" }
}

# ---------------------------------------------------------------------------
# Security Group — outbound only (no inbound services)
# ---------------------------------------------------------------------------
resource "aws_security_group" "ingest" {
  name        = "${local.name_prefix}-ingest"
  description = "Ingest instances - outbound to OpenSearch on app instance and internet"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-ingest-sg" }
}

# ---------------------------------------------------------------------------
# IAM Role for Ingest instances
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ingest" {
  name = "${local.name_prefix}-ingest"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.name_prefix}-ingest-role" }
}

resource "aws_iam_role_policy_attachment" "ingest_ssm" {
  role       = aws_iam_role.ingest.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ingest_permissions" {
  name = "ingest-permissions"
  role = aws_iam_role.ingest.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadData"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.data.arn,
          "${aws_s3_bucket.data.arn}/*",
        ]
      },
      {
        Sid    = "ASGScaleDown"
        Effect = "Allow"
        Action = ["autoscaling:SetDesiredCapacity"]
        Resource = ["arn:aws:autoscaling:${var.aws_region}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${local.name_prefix}-ingest"]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:*:*:log-group:/ec2/${local.name_prefix}*"]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ingest" {
  name = "${local.name_prefix}-ingest"
  role = aws_iam_role.ingest.name
}

# ---------------------------------------------------------------------------
# Launch Template
# ---------------------------------------------------------------------------
resource "aws_launch_template" "ingest" {
  name          = "${local.name_prefix}-ingest"
  image_id      = data.aws_ssm_parameter.al2023_arm.value
  instance_type = "c7g.4xlarge" # Graviton3, 16 vCPU, 32 GB RAM

  iam_instance_profile { arn = aws_iam_instance_profile.ingest.arn }

  network_interfaces {
    associate_public_ip_address = true # Needs internet for pip installs
    security_groups             = [aws_security_group.ingest.id]
  }

  metadata_options {
    http_tokens   = "required" # IMDSv2
    http_endpoint = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50 # OS + pip packages + model cache
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data_ingest.sh", {
    aws_region          = var.aws_region
    data_bucket         = aws_s3_bucket.data.bucket
    opensearch_host     = aws_instance.app.private_ip
    opensearch_port     = "9200"
    opensearch_password = var.opensearch_password
    asg_name            = "${local.name_prefix}-ingest"
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name_prefix}-ingest" }
  }
}

# ---------------------------------------------------------------------------
# Auto Scaling Group — starts at 0, scale to 1 to trigger ingestion
# ---------------------------------------------------------------------------
resource "aws_autoscaling_group" "ingest" {
  name                = "${local.name_prefix}-ingest"
  desired_capacity    = 0 # Scale to 1 via run-ingest.sh
  min_size            = 0
  max_size            = 1
  vpc_zone_identifier = [aws_subnet.public.id]

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "capacity-optimized"
      spot_max_price                           = "0.80"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.ingest.id
        version            = "$Latest"
      }

      override {
        instance_type = "c7g.4xlarge" # 16 vCPU, 32 GB — primary
      }
      override {
        instance_type = "c7g.2xlarge" # 8 vCPU, 16 GB — fallback
      }
      override {
        instance_type = "c6g.4xlarge" # Graviton2 fallback
      }
      override {
        instance_type = "m7g.4xlarge" # Memory-rich fallback
      }
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
