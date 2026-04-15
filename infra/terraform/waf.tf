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

# ── WAF → Kinesis Firehose → S3 archive ──────────────────────────────────────
#
# AWS WAF logging requires the destination Firehose name to start with
# `aws-waf-logs-`. The existing psitta-api-logs-to-s3 stream (logging.tf)
# cannot be reused for that reason, so a second stream is declared here.
# It reuses the same S3 bucket, the same firehose_to_s3 IAM role, and
# the same Glacier IR lifecycle rules — only the object prefix differs
# so WAF logs land under s3://<bucket>/waf/... instead of ecs/...

resource "aws_kinesis_firehose_delivery_stream" "waf_logs" {
  name        = "aws-waf-logs-${var.project}-${var.environment}"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_to_s3.arn
    bucket_arn         = aws_s3_bucket.logs_archive.arn
    buffering_size     = 5
    buffering_interval = 300
    compression_format = "GZIP"

    prefix              = "waf/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "waf-errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
  }

  tags = {
    Project     = var.project
    Environment = var.environment
    Purpose     = "waf-log-archive"
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  resource_arn            = aws_wafv2_web_acl.main.arn
  log_destination_configs = [aws_kinesis_firehose_delivery_stream.waf_logs.arn]
}

# ── SNS topic for security alerts ────────────────────────────────────────────
#
# Target for WAF alarm notifications. No subscribers are wired yet —
# operators can subscribe email / PagerDuty / Slack endpoints to this
# topic out-of-band once the alerting strategy is finalized.

resource "aws_sns_topic" "security_alerts" {
  name = "${var.project}-security-alerts"

  tags = {
    Project     = var.project
    Environment = var.environment
    Purpose     = "security-alerts"
  }
}

# ── Alarm: XSSBodyBlockExceptUploads fires > 0 in 5 min ──────────────────────
#
# This rule only blocks real XSS on non-upload endpoints (uploads are
# excluded via the label-match NOT clause). Any block here is either a
# genuine XSS attempt or a second libinjection false positive that needs
# triage. Either way, someone should look at it.
#
# The "Rule" metric dimension uses the visibility_config.metric_name of
# the target rule, not the rule's display Name. For this rule that
# value is `${var.project}-xss-body-except-uploads`.

resource "aws_cloudwatch_metric_alarm" "xss_body_block_except_uploads" {
  alarm_name          = "${var.project}-waf-xss-body-block"
  alarm_description   = "WAF XSSBodyBlockExceptUploads rule blocked at least one request in the last 5 minutes — investigate potential XSS or libinjection false positive."
  namespace           = "AWS/WAFV2"
  metric_name         = "BlockedRequests"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Region = var.aws_region
    Rule   = "${var.project}-xss-body-except-uploads"
  }

  alarm_actions = [aws_sns_topic.security_alerts.arn]

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── Outputs ──────────────────────────────────────────────────────────────────
output "waf_web_acl_arn" {
  value       = aws_wafv2_web_acl.main.arn
  description = "ARN of the WAF v2 Web ACL protecting the ALB"
}

output "waf_logs_firehose_arn" {
  value       = aws_kinesis_firehose_delivery_stream.waf_logs.arn
  description = "ARN of the Firehose delivery stream shipping WAF logs to S3"
}

output "security_alerts_topic_arn" {
  value       = aws_sns_topic.security_alerts.arn
  description = "SNS topic for WAF / security alarm notifications"
}
