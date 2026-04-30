# ============================================================================
# website.tf — Psitta marketing website (M8a)
# S3 + CloudFront + Route 53 (cross-account) + OIDC deploy role
# Provider: default = psitta-prod (808765744063), alias blowmymind = Route 53 only
# ============================================================================

# ----------------------------------------------------------------------------
# Cross-account provider for Route 53 (hosted zone lives in Blowmymind)
# ----------------------------------------------------------------------------
provider "aws" {
  alias   = "blowmymind"
  region  = "us-east-1"
  profile = "psitta-prod"

  assume_role {
    role_arn     = "arn:aws:iam::010526248733:role/psitta-website-route53-manager"
    session_name = "terraform-psitta-website"
  }
}

# ----------------------------------------------------------------------------
# Locals
# ----------------------------------------------------------------------------
locals {
  website_domain      = "psitta.ai"
  website_www_domain  = "www.psitta.ai"
  website_bucket_name = "psitta-web-prod-${data.aws_caller_identity.current.account_id}"
  website_cert_arn    = "arn:aws:acm:us-east-1:808765744063:certificate/e80c8a20-a321-4e41-9965-b42d2c7b0ba5"
  psitta_zone_id      = "Z0157844SO3Z3QTLZ9UB"
  github_repo         = "thkcyberai/psitta"
  github_branch       = "develop"

  website_tags = {
    Project     = "Psitta"
    Milestone   = "M8a"
    Component   = "website"
    ManagedBy   = "Terraform"
    Environment = "production"
  }
}

# Note: data.aws_caller_identity.current is declared in logging.tf; referenced here.
# Note: Route 53 zone ID is hardcoded in locals (local.psitta_zone_id) rather than
# fetched via data "aws_route53_zone" because that data source calls
# route53:ListTagsForResource, which is intentionally NOT granted to the
# minimum-privilege psitta-website-route53-manager role.

# ----------------------------------------------------------------------------
# S3 bucket (private — CloudFront OAC only)
# ----------------------------------------------------------------------------
resource "aws_s3_bucket" "website" {
  bucket = local.website_bucket_name
  tags   = local.website_tags
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "website" {
  bucket = aws_s3_bucket.website.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# ----------------------------------------------------------------------------
# CloudFront — Origin Access Control
# ----------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "psitta-website-oac"
  description                       = "OAC for psitta.ai static site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ----------------------------------------------------------------------------
# CloudFront — Response Headers Policy (security headers)
# ----------------------------------------------------------------------------
resource "aws_cloudfront_response_headers_policy" "website_security" {
  name    = "psitta-website-security-headers"
  comment = "Security headers for psitta.ai"

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
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    content_security_policy {
      content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://api.psitta.ai; frame-ancestors 'none';"
      override                = true
    }
    xss_protection {
      protection = true
      mode_block = true
      override   = true
    }
  }

  custom_headers_config {
    items {
      header   = "Permissions-Policy"
      value    = "geolocation=(), microphone=(), camera=(), payment=()"
      override = true
    }
  }
}

# ----------------------------------------------------------------------------
# CloudFront Function — www.psitta.ai → psitta.ai (301)
# ----------------------------------------------------------------------------
resource "aws_cloudfront_function" "www_to_apex" {
  name    = "psitta-www-to-apex"
  runtime = "cloudfront-js-2.0"
  comment = "Permanent redirect www.psitta.ai to psitta.ai + directory-index rewrite"
  publish = true
  # Two URL-shape concerns are handled here because S3 REST origins via OAC
  # (unlike the S3 website endpoint) do not resolve directory indexes:
  #   (a) /pricing/ → rewrite to /pricing/index.html (else 403→404)
  #   (b) /pricing  → 301 redirect to /pricing/ (matches Next.js trailingSlash:
  #       true canonical form, preserves query strings — fixes Stripe success_url
  #       and any bare-path direct URL or social-link preview access).
  # default_root_object only handles "/".
  code = <<-EOT
    function handler(event) {
      var request = event.request;
      var host = request.headers.host.value.toLowerCase();
      var uri = request.uri;

      // 1. Permanent redirect www.psitta.ai → psitta.ai (preserve URI + qs)
      if (host === 'www.psitta.ai') {
        return {
          statusCode: 301,
          statusDescription: 'Moved Permanently',
          headers: {
            'location': { value: 'https://psitta.ai' + uri + buildQs(request.querystring) }
          }
        };
      }

      // 2. Apex passes through (default_root_object handles /)
      if (uri === '/') {
        return request;
      }

      // 3. Trailing slash → rewrite to /path/index.html (S3 OAC has no dir-index)
      if (uri.endsWith('/')) {
        request.uri = uri + 'index.html';
        return request;
      }

      // 4. Looks like a file (dot in last segment) → pass through untouched
      var lastSegment = uri.substring(uri.lastIndexOf('/') + 1);
      if (lastSegment.indexOf('.') !== -1) {
        return request;
      }

      // 5. Bare path → 301 to canonical trailing-slash form (preserving qs)
      return {
        statusCode: 301,
        statusDescription: 'Moved Permanently',
        headers: {
          'location': { value: 'https://psitta.ai' + uri + '/' + buildQs(request.querystring) }
        }
      };
    }

    function buildQs(qs) {
      if (!qs) return '';
      var keys = Object.keys(qs);
      if (keys.length === 0) return '';
      var parts = [];
      for (var i = 0; i < keys.length; i++) {
        var k = encodeURIComponent(keys[i]);
        var v = qs[keys[i]];
        if (v.value !== undefined) {
          parts.push(k + '=' + encodeURIComponent(v.value));
        }
        if (v.multiValue) {
          for (var j = 0; j < v.multiValue.length; j++) {
            parts.push(k + '=' + encodeURIComponent(v.multiValue[j].value));
          }
        }
      }
      return '?' + parts.join('&');
    }
  EOT
}

# ----------------------------------------------------------------------------
# CloudFront distribution
# ----------------------------------------------------------------------------
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Psitta marketing website"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  http_version        = "http2and3"
  aliases             = [local.website_domain, local.website_www_domain]
  tags                = local.website_tags

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "s3-website-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-website-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000

    response_headers_policy_id = aws_cloudfront_response_headers_policy.website_security.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.www_to_apex.arn
    }

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = local.website_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# ----------------------------------------------------------------------------
# S3 bucket policy — CloudFront OAC only
# ----------------------------------------------------------------------------
data "aws_iam_policy_document" "website_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.website.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website_bucket_policy.json
}

# ----------------------------------------------------------------------------
# Route 53 — apex + www alias records (cross-account via blowmymind provider)
# ----------------------------------------------------------------------------
resource "aws_route53_record" "apex_a" {
  provider = aws.blowmymind
  zone_id  = local.psitta_zone_id
  name     = local.website_domain
  type     = "A"
  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "apex_aaaa" {
  provider = aws.blowmymind
  zone_id  = local.psitta_zone_id
  name     = local.website_domain
  type     = "AAAA"
  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_a" {
  provider = aws.blowmymind
  zone_id  = local.psitta_zone_id
  name     = local.website_www_domain
  type     = "A"
  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_aaaa" {
  provider = aws.blowmymind
  zone_id  = local.psitta_zone_id
  name     = local.website_www_domain
  type     = "AAAA"
  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

# ----------------------------------------------------------------------------
# GitHub Actions OIDC deploy role (scoped to this bucket + distribution only)
# ----------------------------------------------------------------------------
data "aws_iam_policy_document" "github_oidc_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_repo}:ref:refs/heads/${local.github_branch}"]
    }
  }
}

resource "aws_iam_role" "website_deploy" {
  name               = "psitta-website-deploy-role"
  description        = "GitHub Actions deploy role for Psitta website"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_trust.json
  tags               = local.website_tags
}

data "aws_iam_policy_document" "website_deploy" {
  statement {
    sid    = "S3WebsiteBucketWrite"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      aws_s3_bucket.website.arn,
      "${aws_s3_bucket.website.arn}/*"
    ]
  }
  statement {
    sid    = "CloudFrontInvalidation"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
      "cloudfront:ListInvalidations"
    ]
    resources = [aws_cloudfront_distribution.website.arn]
  }
}

resource "aws_iam_role_policy" "website_deploy" {
  name   = "psitta-website-deploy-policy"
  role   = aws_iam_role.website_deploy.id
  policy = data.aws_iam_policy_document.website_deploy.json
}

# ----------------------------------------------------------------------------
# Outputs
# ----------------------------------------------------------------------------
output "website_bucket_name" {
  description = "S3 bucket name for website assets"
  value       = aws_s3_bucket.website.id
}

output "website_cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.website.id
}

output "website_cloudfront_domain_name" {
  description = "CloudFront domain (for debugging)"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "website_deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions deploy workflow"
  value       = aws_iam_role.website_deploy.arn
}

output "website_urls" {
  description = "Public URLs after DNS propagates"
  value = {
    primary = "https://psitta.ai"
    www     = "https://www.psitta.ai (redirects to primary)"
  }
}
