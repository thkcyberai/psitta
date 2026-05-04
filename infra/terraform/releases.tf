# ============================================================================
# releases.tf — Psitta MSIX distribution (M8d)
# S3 + CloudFront + Route 53 (cross-account) for download.psitta.ai
# Provider: default = psitta-prod (808765744063), alias blowmymind = Route 53
# ============================================================================
#
# Distributes the Windows MSIX package and the .appinstaller manifest that
# drives auto-updates. Tester-facing entry point is:
#   https://download.psitta.ai/psitta.appinstaller
# Versioned MSIX packages live at:
#   https://download.psitta.ai/releases/{version}/psitta.msix
#
# Cross-account provider alias `aws.blowmymind` is declared in website.tf and
# is reused here without redeclaration (provider aliases are root-module-wide).
# data.aws_caller_identity.current is declared in logging.tf.

# ----------------------------------------------------------------------------
# Locals
# ----------------------------------------------------------------------------
locals {
  releases_domain      = "download.psitta.ai"
  releases_bucket_name = "psitta-releases-prod-${data.aws_caller_identity.current.account_id}"
  releases_cert_arn    = "arn:aws:acm:us-east-1:808765744063:certificate/e80c8a20-a321-4e41-9965-b42d2c7b0ba5"
  releases_zone_id     = "Z0157844SO3Z3QTLZ9UB"

  releases_tags = {
    Project     = "Psitta"
    Milestone   = "M8d"
    Component   = "releases"
    ManagedBy   = "Terraform"
    Environment = "production"
  }
}

# ----------------------------------------------------------------------------
# S3 bucket (private — CloudFront OAC only)
# ----------------------------------------------------------------------------
resource "aws_s3_bucket" "releases" {
  bucket = local.releases_bucket_name
  tags   = local.releases_tags
}

resource "aws_s3_bucket_public_access_block" "releases" {
  bucket                  = aws_s3_bucket.releases.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "releases" {
  bucket = aws_s3_bucket.releases.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "releases" {
  bucket = aws_s3_bucket.releases.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "releases" {
  bucket = aws_s3_bucket.releases.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# ----------------------------------------------------------------------------
# CloudFront — Origin Access Control
# ----------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "releases" {
  name                              = "psitta-releases-oac"
  description                       = "OAC for download.psitta.ai (MSIX distribution)"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ----------------------------------------------------------------------------
# CloudFront — Response Headers Policy (minimal: HSTS + nosniff only)
# Release endpoint serves XML manifest + binary MSIX — no HTML, so CSP /
# Frame-Options / XSS-Protection are irrelevant here.
# ----------------------------------------------------------------------------
resource "aws_cloudfront_response_headers_policy" "releases_security" {
  name    = "psitta-releases-security-headers"
  comment = "Security headers for download.psitta.ai"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    content_type_options {
      override = true
    }
  }
}

# ----------------------------------------------------------------------------
# CloudFront distribution
# ----------------------------------------------------------------------------
resource "aws_cloudfront_distribution" "releases" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "Psitta MSIX distribution (download.psitta.ai)"
  price_class     = "PriceClass_100"
  http_version    = "http2and3"
  aliases         = [local.releases_domain]
  tags            = local.releases_tags

  origin {
    domain_name              = aws_s3_bucket.releases.bucket_regional_domain_name
    origin_id                = "s3-releases-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.releases.id
  }

  # ---- Catch-all default behavior (TTL=0; nonexistent keys return 403/404) ----
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-releases-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    response_headers_policy_id = aws_cloudfront_response_headers_policy.releases_security.id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # ---- /psitta.appinstaller — short TTL so updates propagate within 60s ----
  ordered_cache_behavior {
    path_pattern           = "psitta.appinstaller"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-releases-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    min_ttl                = 0
    default_ttl            = 60
    max_ttl                = 60

    response_headers_policy_id = aws_cloudfront_response_headers_policy.releases_security.id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # ---- /releases/* — versioned MSIX paths are immutable, cache 1 year ----
  ordered_cache_behavior {
    path_pattern           = "releases/*"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-releases-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    min_ttl                = 86400
    default_ttl            = 31536000
    max_ttl                = 31536000

    response_headers_policy_id = aws_cloudfront_response_headers_policy.releases_security.id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = local.releases_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# ----------------------------------------------------------------------------
# S3 bucket policy — CloudFront OAC only
# ----------------------------------------------------------------------------
data "aws_iam_policy_document" "releases_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.releases.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.releases.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "releases" {
  bucket = aws_s3_bucket.releases.id
  policy = data.aws_iam_policy_document.releases_bucket_policy.json
}

# ----------------------------------------------------------------------------
# Route 53 — download.psitta.ai alias records (cross-account via blowmymind)
# ----------------------------------------------------------------------------
resource "aws_route53_record" "download_a" {
  provider = aws.blowmymind
  zone_id  = local.releases_zone_id
  name     = local.releases_domain
  type     = "A"
  alias {
    name                   = aws_cloudfront_distribution.releases.domain_name
    zone_id                = aws_cloudfront_distribution.releases.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "download_aaaa" {
  provider = aws.blowmymind
  zone_id  = local.releases_zone_id
  name     = local.releases_domain
  type     = "AAAA"
  alias {
    name                   = aws_cloudfront_distribution.releases.domain_name
    zone_id                = aws_cloudfront_distribution.releases.hosted_zone_id
    evaluate_target_health = false
  }
}

# ----------------------------------------------------------------------------
# Outputs
# ----------------------------------------------------------------------------
output "releases_bucket_name" {
  description = "S3 bucket name for MSIX releases"
  value       = aws_s3_bucket.releases.id
}

output "releases_bucket_arn" {
  description = "S3 bucket ARN for MSIX releases"
  value       = aws_s3_bucket.releases.arn
}

output "releases_cloudfront_distribution_id" {
  description = "CloudFront distribution ID for download.psitta.ai (used for invalidation)"
  value       = aws_cloudfront_distribution.releases.id
}

output "releases_cloudfront_domain_name" {
  description = "CloudFront default domain (for debugging / DNS verification)"
  value       = aws_cloudfront_distribution.releases.domain_name
}

output "releases_url" {
  description = "Public base URL for the releases endpoint"
  value       = "https://${local.releases_domain}"
}

output "download_url" {
  description = "Tester-facing one-click installer URL (.appinstaller manifest)"
  value       = "https://${local.releases_domain}/psitta.appinstaller"
}
