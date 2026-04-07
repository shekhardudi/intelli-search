terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment for remote state:
  # backend "s3" {
  #   bucket = "intelli-search-tf-state"
  #   key    = "single-ec2/terraform.tfstate"
  #   region = "ap-southeast-2"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = local.name_prefix
      Environment = "single-ec2"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name_prefix = "intelli-search-single"
}

# ---------------------------------------------------------------------------
# AWS Resource Group — groups all single-ec2 resources in the Console
# ---------------------------------------------------------------------------
resource "aws_resourcegroups_group" "main" {
  name = local.name_prefix

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [{
        Key    = "Project"
        Values = [local.name_prefix]
      }]
    })
  }

  tags = { Name = "${local.name_prefix}-resource-group" }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Latest Amazon Linux 2023 x86_64 AMI (for app instance)
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Latest Amazon Linux 2023 ARM64 AMI (for ingestion instance)
data "aws_ssm_parameter" "al2023_arm" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}
