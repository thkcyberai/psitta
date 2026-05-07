# ── Pre-Token-Generation v2 Lambda — injects email into access token ──────
#
# Cognito access tokens omit the email claim by default. This Lambda fires
# on every token-issuing event (sign-in, hosted-auth, refresh) and copies
# the verified email user-attribute into the access token's claim set so
# the FastAPI resolver (services/subscription_service.get_effective_plan)
# can match tester_allowlist rows by email without an AdminGetUser round
# trip. Item 11.4 — see CLAUDE.md Key Learning 2026-05-05.

data "archive_file" "pre_token_gen_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/cognito_pre_token_gen"
  output_path = "${path.module}/.build/cognito_pre_token_gen.zip"
}

resource "aws_iam_role" "pre_token_gen" {
  name = "${var.project}-cognito-pre-token-gen"

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

resource "aws_iam_role_policy_attachment" "pre_token_gen_basic_logs" {
  role       = aws_iam_role.pre_token_gen.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "pre_token_gen" {
  name              = "/aws/lambda/${var.project}-cognito-pre-token-gen"
  retention_in_days = 14

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_lambda_function" "pre_token_gen" {
  function_name    = "${var.project}-cognito-pre-token-gen"
  role             = aws_iam_role.pre_token_gen.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.pre_token_gen_zip.output_path
  source_code_hash = data.archive_file.pre_token_gen_zip.output_base64sha256
  timeout          = 5
  memory_size      = 128

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.pre_token_gen]

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_lambda_permission" "cognito_invoke" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_token_gen.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}
