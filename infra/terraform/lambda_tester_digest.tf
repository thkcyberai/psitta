# -- Tester Digest Lambda - Item 9 (daily 8am MT install report) --------------
#
# Cloned from lambda_welcome_email.tf. Differences:
#   * Vendored psycopg2-binary (manylinux2014 wheel) via a null_resource build
#     step - Resend-only Lambda needs no DB driver; this one queries RDS.
#   * VPC config: runs in the same private subnets as ECS so it can reach
#     RDS (private subnet only). New egress-only SG; corresponding ingress
#     rule on the RDS SG via aws_vpc_security_group_ingress_rule (which
#     coexists cleanly with the existing inline ingress block on rds.tf,
#     unlike the older aws_security_group_rule resource).
#   * RDS auth via IAM token, NOT password - execution role holds
#     rds-db:connect on the dedicated psitta_api_digest DB user.
#   * EventBridge Scheduler v2 (cron 0 8 * * ? * in America/Denver, every
#     day including 0-install days).
#
# Pre-apply ops checklist (operator must complete BEFORE terraform apply):
#
#   1. Populate var.rds_dbi_resource_id from the live RDS instance:
#        aws rds describe-db-instances \
#          --db-instance-identifier psitta-db \
#          --query "DBInstances[0].DbiResourceId" \
#          --output text \
#          --profile psitta-prod
#
#   2. Pre-create the dedicated read-only DB user (psql against RDS):
#        CREATE USER psitta_api_digest;
#        GRANT rds_iam TO psitta_api_digest;
#        GRANT CONNECT ON DATABASE psitta TO psitta_api_digest;
#        GRANT USAGE ON SCHEMA public TO psitta_api_digest;
#        GRANT SELECT ON users TO psitta_api_digest;
#        GRANT SELECT ON tester_allowlist TO psitta_api_digest;
#
#   3. Confirm the Resend API key is already present at
#      secrets/psitta/prod/resend-api-key (shared with welcome_email).

# -- Input variable (operator-supplied, no default) ---------------------------
#
# Note on the `null` provider used by null_resource.tester_digest_build below:
# Terraform allows only one `required_providers` block per module, and the
# existing one lives in main.tf (untouchable per Phase C scope). Terraform's
# auto-discovery picks up hashicorp/null based on the null_resource usage
# and installs it at init time - verified working in init output.
variable "rds_dbi_resource_id" {
  description = "RDS DbiResourceId (the dbi-... resource ID, NOT the instance identifier). Used to scope the Lambda rds-db:connect IAM policy to a specific DB instance + user."
  type        = string
}

# -- Build step: vendor psycopg2-binary into a Lambda-shaped package ----------
resource "null_resource" "tester_digest_build" {
  triggers = {
    handler       = filesha256("${path.module}/../lambda/tester_digest/handler.py")
    template_html = filesha256("${path.module}/../lambda/tester_digest/template_digest.html")
    template_text = filesha256("${path.module}/../lambda/tester_digest/template_digest.txt")
    requirements  = filesha256("${path.module}/../lambda/tester_digest/requirements.txt")
    build_script  = filesha256("${path.module}/build_tester_digest.py")
  }

  provisioner "local-exec" {
    command = "python ${path.module}/build_tester_digest.py"
  }
}

# -- Source-zip packaging (reads at apply-time after build runs) --------------
data "archive_file" "tester_digest" {
  type        = "zip"
  source_dir  = "${path.module}/.build/tester_digest_pkg"
  output_path = "${path.module}/.build/tester_digest.zip"

  depends_on = [null_resource.tester_digest_build]
}

# -- IAM: execution role ------------------------------------------------------
resource "aws_iam_role" "tester_digest" {
  name = "${var.project}-tester-digest"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "tester_digest_basic" {
  role       = aws_iam_role.tester_digest.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC-attached Lambdas need ENI manage permissions - required for the function
# to attach to the private subnets at cold-start. Without this, every cold
# invocation fails with "EFSMountFailure"-style ENI errors.
resource "aws_iam_role_policy_attachment" "tester_digest_vpc" {
  role       = aws_iam_role.tester_digest.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Least-privilege: only the shared Resend secret, NOT app_secrets.
resource "aws_iam_role_policy" "tester_digest_secrets" {
  name = "${var.project}-tester-digest-secrets-read"
  role = aws_iam_role.tester_digest.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.resend_api_key.arn
    }]
  })
}

# IAM auth to RDS - scoped to the dedicated DB user only. Format:
#   arn:aws:rds-db:<region>:<account>:dbuser:<DbiResourceId>/<rds-user>
# DbiResourceId is fed in via var.rds_dbi_resource_id (operator-supplied).
resource "aws_iam_role_policy" "tester_digest_rds_connect" {
  name = "${var.project}-tester-digest-rds-connect"
  role = aws_iam_role.tester_digest.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "rds-db:connect"
      Resource = "arn:aws:rds-db:${var.aws_region}:${data.aws_caller_identity.current.account_id}:dbuser:${var.rds_dbi_resource_id}/psitta_api_digest"
    }]
  })
}

# Async-invoke DLQ write - Lambda's DLQ machinery uses the function's
# execution role to call sqs:SendMessage.
resource "aws_iam_role_policy" "tester_digest_dlq" {
  name = "${var.project}-tester-digest-dlq-send"
  role = aws_iam_role.tester_digest.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.tester_digest_dlq.arn
    }]
  })
}

# -- Security group for the Lambda's ENI --------------------------------------
#
# Egress-only. Two rules:
#   * TCP 5432 to RDS SG  - private VPC path, narrow scope
#   * TCP 443 to anywhere - Resend API + Secrets Manager
#
# (Secrets Manager could be reached more narrowly via a VPC endpoint, but no
#  endpoint exists in this account today; ECS reaches Secrets Manager via
#  the same broad HTTPS egress - mirroring that pattern keeps the design
#  predictable and matches the working ECS network path.)
resource "aws_security_group" "tester_digest_lambda" {
  name        = "${var.project}-tester-digest-lambda-sg"
  description = "Egress for psitta-tester-digest Lambda - RDS + HTTPS"
  vpc_id      = aws_vpc.main.id

  egress {
    description     = "PostgreSQL to RDS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.rds.id]
  }

  egress {
    description = "HTTPS to Resend API + AWS service endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-tester-digest-lambda-sg"
    Project     = var.project
    Environment = var.environment
  }
}

# Explicit SG-scoped ingress on the RDS SG. The existing rds.tf already
# allows 10.0.0.0/16 broadly, so this rule is operationally redundant but
# kept for documentation/auditability. Uses aws_vpc_security_group_ingress_rule
# (5.x-era) which coexists with the inline ingress block on aws_security_group.rds.
resource "aws_vpc_security_group_ingress_rule" "rds_from_tester_digest" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.tester_digest_lambda.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "psitta-tester-digest Lambda to RDS"

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# -- CloudWatch log group -----------------------------------------------------
resource "aws_cloudwatch_log_group" "tester_digest" {
  name              = "/aws/lambda/${var.project}-tester-digest"
  retention_in_days = 14

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# -- SQS DLQ for failed async invocations -------------------------------------
resource "aws_sqs_queue" "tester_digest_dlq" {
  name                      = "${var.project}-tester-digest-dlq"
  message_retention_seconds = 1209600 # 14 days (SQS maximum)
  kms_master_key_id         = "alias/aws/sqs"

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# -- Lambda function ----------------------------------------------------------
resource "aws_lambda_function" "tester_digest" {
  function_name    = "${var.project}-tester-digest"
  role             = aws_iam_role.tester_digest.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.tester_digest.output_path
  source_code_hash = data.archive_file.tester_digest.output_base64sha256
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.tester_digest_lambda.id]
  }

  environment {
    variables = {
      LOG_LEVEL          = "INFO"
      RESEND_SECRET_NAME = aws_secretsmanager_secret.resend_api_key.name
      FROM_ADDRESS       = "Psitta Tester Digest <digest@psitta.ai>"
      TO_ADDRESS         = "luis@psitta.ai"
      RDS_HOST           = aws_db_instance.main.address
      RDS_PORT           = tostring(aws_db_instance.main.port)
      RDS_DB_NAME        = aws_db_instance.main.db_name
      RDS_USER           = "psitta_api_digest"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.tester_digest_dlq.arn
  }

  depends_on = [
    aws_cloudwatch_log_group.tester_digest,
    aws_iam_role_policy.tester_digest_secrets,
    aws_iam_role_policy.tester_digest_rds_connect,
    aws_iam_role_policy.tester_digest_dlq,
    aws_iam_role_policy_attachment.tester_digest_vpc,
  ]

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# -- DLQ depth alarm - paged via the operational alarms topic -----------------
# Wired to aws_sns_topic.alarms (P3-9, observability.tf) - pages on any DLQ
# arrival within a 5-minute window.
resource "aws_cloudwatch_metric_alarm" "tester_digest_dlq_depth" {
  alarm_name          = "${var.project}-tester-digest-dlq-depth"
  alarm_description   = "Tester-digest Lambda DLQ depth. Non-zero = the daily digest Lambda failed all retries; check /aws/lambda/psitta-tester-digest log group."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.tester_digest_dlq.name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# -- EventBridge Scheduler v2 - daily 8am MT, every day -----------------------
#
# Why aws_scheduler_schedule (EventBridge Scheduler v2) over the older
# aws_cloudwatch_event_rule: the new resource handles timezone-aware cron
# natively (schedule_expression_timezone) so DST is handled by AWS rather
# than via manual UTC offset arithmetic.
#
# cron format: minute hour day-of-month month day-of-week year
# "0 8 * * ? *" = 08:00 every day; ? in day-of-month + * in day-of-week
# means "any day-of-month, every day-of-week" (the EventBridge cron dialect
# requires exactly one of day-of-month or day-of-week to be '?' since both
# can't be specified concretely at once).
resource "aws_iam_role" "tester_digest_scheduler" {
  name = "${var.project}-tester-digest-scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "tester_digest_scheduler_invoke" {
  name = "${var.project}-tester-digest-scheduler-invoke"
  role = aws_iam_role.tester_digest_scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.tester_digest.arn
    }]
  })
}

resource "aws_scheduler_schedule" "tester_digest_daily" {
  name        = "${var.project}-tester-digest-daily"
  description = "Daily 8am MT trigger for psitta-tester-digest Lambda."

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(0 8 * * ? *)"
  schedule_expression_timezone = "America/Denver"

  target {
    arn      = aws_lambda_function.tester_digest.arn
    role_arn = aws_iam_role.tester_digest_scheduler.arn

    retry_policy {
      maximum_event_age_in_seconds = 3600 # 1 hour - past that, give up; DLQ catches the failure
      maximum_retry_attempts       = 2
    }
  }
}

# Resource-based permission on the Lambda - defense in depth alongside the
# role-based path above. Matches the welcome_email pattern of explicit
# lambda_permission for the invoking principal.
resource "aws_lambda_permission" "scheduler_invoke_tester_digest" {
  statement_id  = "AllowSchedulerInvokeTesterDigest"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tester_digest.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.tester_digest_daily.arn
}
