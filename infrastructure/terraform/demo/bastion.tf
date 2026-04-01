# ---------------------------------------------------------------------------
# Bastion host — lightweight SSM tunnel target for OpenSearch Dashboard access
# t4g.nano (~$3/month), private subnet, no SSH, no public IP
# ---------------------------------------------------------------------------

# --- IAM Role (SSM only — least privilege) ---------------------------------

resource "aws_iam_role" "bastion" {
  name               = "${local.name_prefix}-bastion"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${local.name_prefix}-bastion"
  role = aws_iam_role.bastion.name
}

# --- Security Group (no ingress, HTTPS egress to VPC only) -----------------

resource "aws_security_group" "bastion" {
  name        = "${local.name_prefix}-bastion"
  description = "Bastion - SSM tunnel to OpenSearch, no inbound"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "HTTPS to VPC (OpenSearch + VPC endpoints)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${local.name_prefix}-bastion" }
}

# --- EC2 Instance ----------------------------------------------------------

resource "aws_instance" "bastion" {
  ami                    = data.aws_ssm_parameter.al2023_arm.value
  instance_type          = "t4g.nano"
  subnet_id              = aws_subnet.private[0].id
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  vpc_security_group_ids = [aws_security_group.bastion.id]

  metadata_options {
    http_tokens   = "required" # IMDSv2 only
    http_endpoint = "enabled"
  }

  tags = { Name = "${local.name_prefix}-bastion" }
}
