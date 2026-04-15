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

        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }

        rule_action_override {
          name = "SizeRestrictions_URIPATH"
          action_to_use {
            count {}
          }
        }

        rule_action_override {
          name = "SizeRestrictions_QUERYSTRING"
          action_to_use {
            count {}
          }
        }

        # CrossSiteScripting_BODY is demoted to Count because libinjection_xss
        # false-positives on deflate-compressed DOCX/image upload bodies (the
        # compressed byte stream incidentally contains `<!` / `<me` tokens that
        # libinjection parses as HTML tag openers). XSS blocking is re-applied
        # at priority 5 for every request EXCEPT POST /api/v1/documents/*.
        rule_action_override {
          name = "CrossSiteScripting_BODY"
          action_to_use {
            count {}
          }
        }
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

  # ── XSS body block for every endpoint EXCEPT document/cover uploads ───────
  # Re-blocks requests that the CRS CrossSiteScripting_BODY sub-rule labelled
  # as XSS (it is demoted to Count at priority 1). The NOT clause excludes
  # POST /api/v1/documents/* — the only endpoints that accept binary bodies
  # (DOCX, PDF, cover images) where libinjection_xss false-positives on the
  # deflate byte stream. Every other endpoint continues to block on XSS.
  rule {
    name     = "XSSBodyBlockExceptUploads"
    priority = 5

    action {
      block {}
    }

    statement {
      and_statement {
        statement {
          label_match_statement {
            scope = "LABEL"
            key   = "awswaf:managed:aws:core-rule-set:CrossSiteScripting_Body"
          }
        }
        statement {
          not_statement {
            statement {
              and_statement {
                statement {
                  byte_match_statement {
                    search_string         = "POST"
                    positional_constraint = "EXACTLY"

                    field_to_match {
                      method {}
                    }

                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  byte_match_statement {
                    search_string         = "/api/v1/documents/"
                    positional_constraint = "STARTS_WITH"

                    field_to_match {
                      uri_path {}
                    }

                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-xss-body-except-uploads"
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
