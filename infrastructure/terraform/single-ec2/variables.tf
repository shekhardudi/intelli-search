variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-2"
}

variable "instance_type" {
  description = "EC2 instance type (needs 32 GB RAM)"
  type        = string
  default     = "r6i.xlarge" # 4 vCPU, 32 GB RAM
}

variable "opensearch_password" {
  description = "Password for OpenSearch admin user (min 8 chars, mixed case + symbols)"
  type        = string
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key for intent classification"
  type        = string
  sensitive   = true
}

variable "tavily_api_key" {
  description = "Tavily API key for agentic web search (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair for SSH access (optional — SSM is preferred)"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance (only used if ssh_key_name is set)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "enable_cloudfront" {
  description = "Create a CloudFront distribution in front of the app (adds HTTPS + CDN caching)"
  type        = bool
  default     = false
}
