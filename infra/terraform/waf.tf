# ── WAF v2 Web ACL ───────────────────────────────────────────────────────────
resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project}-waf"
  description = "WAF for psitta ALB - OWASP, SQLi, bad inputs, rate limiting"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # ── AWS Managed Rules: Common Rule Set (OWASP Top 10, XSS) ────────────────
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # ── AWS Managed Rules: Known Bad Inputs ────────────────────────────────────
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # ── AWS Managed Rules: SQL Injection ───────────────────────────────────────
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # ── Rate Limiting: 2000 requests per 5 minutes per IP ─────────────────────
  rule {
    name     = "RateLimitPerIP"
    priority = 4

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── WAF Association with ALB ─────────────────────────────────────────────────
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# ── Outputs ──────────────────────────────────────────────────────────────────
output "waf_web_acl_arn" {
  value       = aws_wafv2_web_acl.main.arn
  description = "ARN of the WAF v2 Web ACL protecting the ALB"
}
