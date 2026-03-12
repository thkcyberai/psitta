# ── CloudFront Distribution for Audio ────────────────────────────────────────
resource "aws_cloudfront_origin_access_control" "audio" {
  name                              = "${var.project}-audio-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "audio" {
  enabled             = true
  comment             = "Psitta audio delivery CDN"
  default_root_object = ""

  origin {
    domain_name              = aws_s3_bucket.audio.bucket_regional_domain_name
    origin_id                = "audio-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.audio.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "audio-s3"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── S3 bucket policy: allow CloudFront only ───────────────────────────────────
resource "aws_s3_bucket_policy" "audio" {
  bucket = aws_s3_bucket.audio.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontAccess"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.audio.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.audio.arn
        }
      }
    }]
  })
}

output "cloudfront_domain" {
  value       = aws_cloudfront_distribution.audio.domain_name
  description = "CloudFront domain for audio delivery"
}
