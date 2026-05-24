# ──────────────────────────────────────────────────────────────────────
# observability.tf — P3-9
#
# Codifies the operational observability stack that was bootstrapped
# via AWS CLI (May 12–22). Distinct from the WAF/security alerts in
# waf.tf — that stack uses aws_sns_topic.security_alerts
# (psitta-security-alerts) for WAF-class alarms; this one uses
# aws_sns_topic.alarms (psitta-alarms-prod) for operational alarms
# (Lambda errors, DLQ depth, billing webhook failure metric).
#
# Every resource declared in this file ALREADY EXISTS in AWS. The
# corresponding `terraform import` commands MUST be run before the
# next `terraform apply`, or apply will fail with AlreadyExists
# errors. Expected import IDs (P3-9 runbook):
#
#   aws_sns_topic.alarms                  arn:aws:sns:us-east-1:808765744063:psitta-alarms-prod
#   aws_sns_topic_subscription.alarms_email arn:aws:sns:us-east-1:808765744063:psitta-alarms-prod:<sub-uuid>
#   aws_cloudwatch_metric_alarm.pre_token_gen_errors  psitta-cognito-pre-token-gen-errors
#   aws_cloudwatch_log_metric_filter.billing_webhook_success  /ecs/psitta-api:psitta-billing-webhook-success
#   aws_cloudwatch_log_metric_filter.billing_webhook_failure  /ecs/psitta-api:psitta-billing-webhook-failure
#   aws_cloudwatch_dashboard.automation   Psitta-Automation
# ──────────────────────────────────────────────────────────────────────

# ── SNS topic for operational alarms ─────────────────────────────────
resource "aws_sns_topic" "alarms" {
  name = "${var.project}-alarms-prod"

  tags = {
    Project     = var.project
    Environment = var.environment
    Purpose     = "alarm-notifications"
  }
}

# ── Email subscription (confirmed) ───────────────────────────────────
#
# The live subscription is already CONFIRMED. Destroy-and-recreate
# would re-fire the SNS confirmation email and require manual click,
# leaving alarms unable to page until reconfirmed. The import brings
# the confirmed sub under TF management; prevent_destroy is a guard
# against accidental `terraform destroy` or resource removal that
# would force a re-subscribe.
resource "aws_sns_topic_subscription" "alarms_email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = "luis@psitta.ai"

  lifecycle {
    prevent_destroy = true

    # confirmation_timeout_in_minutes and endpoint_auto_confirms are
    # TF-creation-time metadata only -- consumed during subscription
    # confirmation polling (HTTP/HTTPS) or PagerDuty-style auto-confirm.
    # Email protocol uses neither, and SNS does not store them server-
    # side, so the AWS provider's Read function leaves them null after
    # import. Explicit declaration would show "+ null -> default" each
    # plan; ignore_changes tells TF to stop comparing state vs config
    # for these two fields. Safe because both fields are inert once the
    # subscription is confirmed.
    ignore_changes = [
      confirmation_timeout_in_minutes,
      endpoint_auto_confirms,
    ]
  }
}

# ── Alarm: Cognito Pre-Token-Gen Lambda errors ───────────────────────
#
# Synchronous Cognito trigger — every error blocks a user login. There
# is no DLQ for synchronous-invocation Lambda errors, so this alarm is
# the only signal. Threshold 0 / period 300 / evaluation 1 = page on
# first error in any 5-minute window.
resource "aws_cloudwatch_metric_alarm" "pre_token_gen_errors" {
  alarm_name          = "${var.project}-cognito-pre-token-gen-errors"
  alarm_description   = "Cognito PreTokenGeneration Lambda errors. Synchronous trigger -- every error means a user could not log in. No DLQ exists for this trigger; this alarm is the only signal."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.pre_token_gen.function_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── Metric filters: Stripe billing webhook outcomes ──────────────────
#
# Parsed from API JSON logs on /ecs/psitta-api. The `path` and `event`
# constraints scope to webhook-handler completions only; the status_code
# range distinguishes 2xx success from 4xx/5xx failure. default_value=0
# emits a zero data-point per log-pull-interval when no events match,
# producing a continuous CloudWatch metric instead of sparse data
# (required for accurate ratio alarms).
resource "aws_cloudwatch_log_metric_filter" "billing_webhook_success" {
  name           = "${var.project}-billing-webhook-success"
  log_group_name = aws_cloudwatch_log_group.api.name
  pattern        = "{ $.path = \"/api/v1/billing/webhook\" && $.event = \"request.completed\" && $.status_code >= 200 && $.status_code < 300 }"

  metric_transformation {
    name          = "webhook_success"
    namespace     = "Psitta/Billing"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "billing_webhook_failure" {
  name           = "${var.project}-billing-webhook-failure"
  log_group_name = aws_cloudwatch_log_group.api.name
  pattern        = "{ $.path = \"/api/v1/billing/webhook\" && $.event = \"request.completed\" && ( $.status_code < 200 || $.status_code >= 300 ) }"

  metric_transformation {
    name          = "webhook_failure"
    namespace     = "Psitta/Billing"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

# ── CloudWatch dashboard: Psitta-Automation ──────────────────────────
#
# 19 widgets, body stored in the sidecar file dashboards/automation.json
# (extracted byte-exact from `aws cloudwatch get-dashboard` with trailing
# whitespace stripped).
#
# Uses file() — the AWS provider's JSON-equivalence diff suppression on
# dashboard_body handles whitespace and key-order normalization. If a
# future plan reports a spurious dashboard_body diff after import, the
# operator-side fix is to switch to:
#   dashboard_body = jsonencode(jsondecode(file(...)))
# which canonicalizes the rendered string.
resource "aws_cloudwatch_dashboard" "automation" {
  dashboard_name = "Psitta-Automation"
  dashboard_body = file("${path.module}/dashboards/automation.json")
}

# ── Outputs ──────────────────────────────────────────────────────────
output "alarms_topic_arn" {
  value       = aws_sns_topic.alarms.arn
  description = "SNS topic for operational alarms (Lambda errors, DLQ depth, billing webhook failures). Distinct from security_alerts_topic_arn."
}
