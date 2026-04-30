# ---------------------------------------------------------------------------
# CloudFront Distribution — CDN + HTTPS in front of the EC2 app instance
#
# Origin: EC2 public DNS on port 80 (nginx reverse proxy)
# Behaviour: forwards requests, caches static assets
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "app" {
  count = var.enable_cloudfront ? 1 : 0

  enabled             = true
  comment             = "${local.name_prefix} app distribution"
  default_root_object = ""
  price_class         = "PriceClass_200" # US, Canada, Europe, Asia, Middle East, Africa
  http_version        = "http2and3"

  # --- Origin: EC2 instance (nginx on port 80) ---
  origin {
    domain_name = aws_instance.app.public_dns
    origin_id   = "ec2-app"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = 60
    }
  }

  # --- Default behaviour: forward everything (dynamic API + SPA) ---
  default_cache_behavior {
    target_origin_id       = "ec2-app"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Host", "Origin", "Accept", "Authorization"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # --- Cache static assets (JS, CSS, images, fonts) ---
  ordered_cache_behavior {
    path_pattern           = "/assets/*"
    target_origin_id       = "ec2-app"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      headers      = []

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # --- Restrictions (no geo-blocking) ---
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # --- Use default CloudFront certificate (*.cloudfront.net) ---
  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = { Name = "${local.name_prefix}-cloudfront" }

  depends_on = [aws_instance.app]
}
