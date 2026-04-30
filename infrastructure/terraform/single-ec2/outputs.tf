output "instance_public_ip" {
  description = "EC2 public IP (dynamic — changes on stop/start)"
  value       = aws_instance.app.public_ip
}

output "instance_id" {
  description = "EC2 instance ID (for SSM sessions)"
  value       = aws_instance.app.id
}

output "app_url" {
  description = "Application URL (port 80 via nginx reverse proxy)"
  value       = "http://${aws_instance.app.public_ip}"
}

output "opensearch_dashboards_url" {
  description = "OpenSearch Dashboards URL"
  value       = "http://${aws_instance.app.public_ip}:5601"
}

output "ssm_connect_command" {
  description = "Connect to the instance via SSM (no SSH key needed)"
  value       = "aws ssm start-session --target ${aws_instance.app.id}"
}

output "data_bucket_name" {
  description = "S3 bucket for staging ingestion data (e.g. companies_sorted.csv)"
  value       = aws_s3_bucket.data.id
}

output "upload_csv_command" {
  description = "Upload companies_sorted.csv to the data bucket"
  value       = "aws s3 cp data-pipeline/companies_sorted.csv s3://${aws_s3_bucket.data.id}/companies_sorted.csv"
}

output "upload_pipeline_command" {
  description = "Package and upload data-pipeline code to S3"
  value       = "tar czf /tmp/data-pipeline.tar.gz -C data-pipeline . && aws s3 cp /tmp/data-pipeline.tar.gz s3://${aws_s3_bucket.data.id}/data-pipeline.tar.gz"
}

output "ingest_asg_name" {
  description = "Ingestion ASG name (scale to 1 to trigger ingestion)"
  value       = aws_autoscaling_group.ingest.name
}

output "run_ingestion_command" {
  description = "Trigger data ingestion"
  value       = "aws autoscaling set-desired-capacity --auto-scaling-group-name ${aws_autoscaling_group.ingest.name} --desired-capacity 1 --region ${var.aws_region}"
}

# ---------------------------------------------------------------------------
# CloudFront
# ---------------------------------------------------------------------------
output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name (HTTPS)"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.app[0].domain_name : null
}

output "cloudfront_url" {
  description = "Application URL via CloudFront (HTTPS)"
  value       = var.enable_cloudfront ? "https://${aws_cloudfront_distribution.app[0].domain_name}" : null
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.app[0].id : null
}
