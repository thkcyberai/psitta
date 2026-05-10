# ── Welcome Email Lambda — Cognito Post-Confirmation trigger ─────────────────
#
# Sends Template D ("Welcome to Psitta — your alpha access is active") to
# every email-verified Cognito signup. Cognito enforces exactly-once
# semantics on Post-Confirmation, so no application-level idempotency
# column is needed on users.welcome_email_sent_at. The Resend API key is
# read from Secrets Manager (psitta/prod/resend-api-key, value populated
# manually out-of-band — never in Terraform state).
#
# Failure mode: any Resend HTTP error or network exception re-raises;
# Cognito routes the failed async invocation to the SQS DLQ
# (psitta-welcome-email-dlq, 14d retention, KMS-encrypted at rest).
# A CloudWatch alarm fires when the DLQ depth exceeds 0.

# ── Source-zip packaging ────────────────────────────────────────────────────
data "archive_file" "welcome_email" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/welcome_email"
  output_path = "${path.module}/.build/welcome_email.zip"

  excludes = [
    ".gitignore",
    ".build",
    "__pycache__",
  ]
}

# ── IAM: execution role ─────────────────────────────────────────────────────
resource "aws_iam_role" "welcome_email" {
  name = "${var.project}-welcome-email"

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

resource "aws_iam_role_policy_attachment" "welcome_email_basic" {
  role       = aws_iam_role.welcome_email.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ── IAM: read the resend-api-key secret (least-privilege, no wildcard) ──────
# Scoped to the resend-api-key ARN ONLY — explicitly NOT psitta/prod/app-secrets.
resource "aws_iam_role_policy" "welcome_email_secrets" {
  name = "${var.project}-welcome-email-secrets-read"
  role = aws_iam_role.welcome_email.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.resend_api_key.arn
    }]
  })
}

# ── IAM: write to the DLQ on async-invoke failure ───────────────────────────
# Lambda's asynchronous DLQ machinery uses the function's execution role to
# call sqs:SendMessage, so the role itself needs the permission.
resource "aws_iam_role_policy" "welcome_email_dlq" {
  name = "${var.project}-welcome-email-dlq-send"
  role = aws_iam_role.welcome_email.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.welcome_email_dlq.arn
    }]
  })
}

# ── CloudWatch log group ────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "welcome_email" {
  name              = "/aws/lambda/${var.project}-welcome-email"
  retention_in_days = 14

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── SQS DLQ for failed async invocations ────────────────────────────────────
resource "aws_sqs_queue" "welcome_email_dlq" {
  name                      = "${var.project}-welcome-email-dlq"
  message_retention_seconds = 1209600 # 14 days (SQS maximum)
  kms_master_key_id         = "alias/aws/sqs"

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── Lambda function ─────────────────────────────────────────────────────────
resource "aws_lambda_function" "welcome_email" {
  function_name    = "${var.project}-welcome-email"
  role             = aws_iam_role.welcome_email.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.welcome_email.output_path
  source_code_hash = data.archive_file.welcome_email.output_base64sha256
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      LOG_LEVEL          = "INFO"
      RESEND_SECRET_NAME = aws_secretsmanager_secret.resend_api_key.name
      FROM_ADDRESS       = "Psitta <welcome@psitta.ai>"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.welcome_email_dlq.arn
  }

  depends_on = [
    aws_cloudwatch_log_group.welcome_email,
    aws_iam_role_policy.welcome_email_secrets,
    aws_iam_role_policy.welcome_email_dlq,
  ]

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── Permit Cognito to invoke the function ───────────────────────────────────
resource "aws_lambda_permission" "cognito_invoke_welcome_email" {
  statement_id  = "AllowCognitoInvokeWelcomeEmail"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.welcome_email.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}

# ── DLQ depth alarm — paged when any message lands ──────────────────────────
# TODO: Wire SNS topic when ops alert routing is set up. For now alarm is
# visible only in the CloudWatch console; no paging.
resource "aws_cloudwatch_metric_alarm" "welcome_email_dlq_depth" {
  alarm_name          = "${var.project}-welcome-email-dlq-depth"
  alarm_description   = "Welcome Email DLQ has unread messages — investigate failed sends."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.welcome_email_dlq.name
  }

  alarm_actions = []

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}
