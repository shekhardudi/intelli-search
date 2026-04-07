# ---------------------------------------------------------------------------
# Security Group — HTTP/HTTPS for CloudFront, app ports, optional SSH
# ---------------------------------------------------------------------------
resource "aws_security_group" "instance" {
  name_prefix = "${local.name_prefix}-instance-"
  description = "Allow HTTP (nginx), Dashboards, and optionally SSH"
  vpc_id      = aws_vpc.main.id

  # HTTP — CloudFront connects to origin on port 80
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Frontend (5173) and Backend (8000) are accessed via nginx on port 80.
  # No need to expose them publicly.

  # OpenSearch Dashboards (5601)
  ingress {
    description = "OpenSearch Dashboards"
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # OpenSearch (9200) — from ingestion instances
  ingress {
    description     = "OpenSearch from ingest"
    from_port       = 9200
    to_port         = 9200
    protocol        = "tcp"
    security_groups = [aws_security_group.ingest.id]
  }

  # SSH — only if key pair is provided
  dynamic "ingress" {
    for_each = var.ssh_key_name != "" ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.allowed_ssh_cidr]
    }
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-instance-sg" }

  lifecycle {
    create_before_destroy = true
  }
}
