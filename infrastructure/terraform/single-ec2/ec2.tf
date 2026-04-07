# ---------------------------------------------------------------------------
# IAM Role — SSM access for remote management (no SSH needed)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "instance" {
  name = "${local.name_prefix}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.name_prefix}-instance-role" }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${local.name_prefix}-instance-profile"
  role = aws_iam_role.instance.name
}

# ---------------------------------------------------------------------------
# EC2 Instance — runs all 4 containers via docker compose
# ---------------------------------------------------------------------------
resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.instance.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  key_name = var.ssh_key_name != "" ? var.ssh_key_name : null

  # 80 GB gp3 root volume (OS + Docker images + OpenSearch data)
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 80
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_tokens   = "required" # IMDSv2 enforced
    http_endpoint = "enabled"
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    opensearch_password = var.opensearch_password
    openai_api_key      = var.openai_api_key
    tavily_api_key      = var.tavily_api_key
  }))

  tags = {
    Name = "${local.name_prefix}-app"
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# No Elastic IP — instance gets a dynamic public IP from the subnet.
# IP changes on stop/start but manage-instance.sh reads the current IP.
# This avoids the $3.65/mo EIP charge while stopped.
