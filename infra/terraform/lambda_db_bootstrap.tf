# -- ONE-TIME bootstrap Lambda - creates the psitta_api_digest DB role --------
#
# ONE-TIME BOOTSTRAP - delete after successful invocation per operator ops
# checklist. The Lambda is intended to be deployed, invoked exactly once
# synchronously (RequestResponse), then destroyed within ~10 minutes.
#
# Broader Secrets Manager grant accepted because Lambda lifespan is ~10
# minutes (deploy -> invoke -> destroy). MUST be removed via
# `terraform destroy -target=aws_lambda_function.db_bootstrap ...` after
# successful invocation. If you find this Lambda still deployed >24h
# after creation, that is a bug.
#
# Cleanup commands (run AFTER successful invocation):
#   terraform destroy \
#     -target=aws_lambda_function.db_bootstrap \
#     -target=aws_iam_role.db_bootstrap \
#     -target=aws_iam_role_policy.db_bootstrap_secrets \
#     -target=aws_iam_role_policy_attachment.db_bootstrap_basic \
#     -target=aws_iam_role_policy_attachment.db_bootstrap_vpc \
#     -target=aws_cloudwatch_log_group.db_bootstrap \
#     -target=aws_security_group.db_bootstrap_lambda \
#     -target=aws_vpc_security_group_ingress_rule.rds_from_db_bootstrap \
#     -target=null_resource.db_bootstrap_build \
#     -var="rds_dbi_resource_id=<the-dbi-id>"
#
# Then delete the source files:
#   rm -rf infra/lambda/db_bootstrap/
#   rm infra/terraform/build_db_bootstrap.py
#   rm infra/terraform/lambda_db_bootstrap.tf

# -- Build step: vendor psycopg2-binary into a Lambda-shaped package ----------
resource "null_resource" "db_bootstrap_build" {
  triggers = {
    handler      = filesha256("${path.module}/../lambda/db_bootstrap/handler.py")
    requirements = filesha256("${path.module}/../lambda/db_bootstrap/requirements.txt")
    build_script = filesha256("${path.module}/build_db_bootstrap.py")
  }

  provisioner "local-exec" {
    command = "python ${path.module}/build_db_bootstrap.py"
  }
}

# -- Source-zip packaging (reads at apply-time after build runs) --------------
data "archive_file" "db_bootstrap" {
  type        = "zip"
  source_dir  = "${path.module}/.build/db_bootstrap_pkg"
  output_path = "${path.module}/.build/db_bootstrap.zip"

  depends_on = [null_resource.db_bootstrap_build]
}

# -- IAM: execution role ------------------------------------------------------
resource "aws_iam_role" "db_bootstrap" {
  name = "${var.project}-db-bootstrap"

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
    Lifecycle   = "one-time-bootstrap-delete-after-invocation"
  }
}

resource "aws_iam_role_policy_attachment" "db_bootstrap_basic" {
  role       = aws_iam_role.db_bootstrap.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC-attached Lambdas need ENI manage permissions - required to attach
# to private subnets at cold-start.
resource "aws_iam_role_policy_attachment" "db_bootstrap_vpc" {
  role       = aws_iam_role.db_bootstrap.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Scoped to the bundled app-secrets ARN - broader than ideal (Lambda
# could read ElevenLabs / Azure / Anthropic keys + the app secret_key)
# but acceptable because the Lambda's lifespan is ~10 minutes (deploy ->
# invoke -> destroy) per the cleanup checklist above. The same principal
# that could exploit this grant (anyone with lambda:GetFunctionConfiguration
# in this account) could already read app-secrets directly via other paths.
resource "aws_iam_role_policy" "db_bootstrap_secrets" {
  name = "${var.project}-db-bootstrap-secrets-read"
  role = aws_iam_role.db_bootstrap.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.app_secrets.arn
    }]
  })
}

# -- Security group for the Lambda's ENI --------------------------------------
#
# Same egress shape as tester_digest_lambda - TCP 5432 to RDS SG and TCP
# 443 to anywhere (Secrets Manager). Distinct SG so it can be cleanly
# torn down with the rest of the bootstrap resources.
resource "aws_security_group" "db_bootstrap_lambda" {
  name        = "${var.project}-db-bootstrap-lambda-sg"
  description = "Egress for psitta-db-bootstrap one-time Lambda - RDS + HTTPS"
  vpc_id      = aws_vpc.main.id

  egress {
    description     = "PostgreSQL to RDS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.rds.id]
  }

  egress {
    description = "HTTPS to AWS Secrets Manager"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-db-bootstrap-lambda-sg"
    Project     = var.project
    Environment = var.environment
    Lifecycle   = "one-time-bootstrap-delete-after-invocation"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_db_bootstrap" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.db_bootstrap_lambda.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "psitta-db-bootstrap one-time Lambda to RDS"

  tags = {
    Project     = var.project
    Environment = var.environment
    Lifecycle   = "one-time-bootstrap-delete-after-invocation"
  }
}

# -- CloudWatch log group -----------------------------------------------------
resource "aws_cloudwatch_log_group" "db_bootstrap" {
  name              = "/aws/lambda/${var.project}-db-bootstrap"
  retention_in_days = 14

  tags = {
    Project     = var.project
    Environment = var.environment
    Lifecycle   = "one-time-bootstrap-delete-after-invocation"
  }
}

# -- Lambda function (NO DLQ - sync invoke only, manual error handling) ------
resource "aws_lambda_function" "db_bootstrap" {
  function_name    = "${var.project}-db-bootstrap"
  role             = aws_iam_role.db_bootstrap.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.db_bootstrap.output_path
  source_code_hash = data.archive_file.db_bootstrap.output_base64sha256
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.db_bootstrap_lambda.id]
  }

  environment {
    variables = {
      LOG_LEVEL              = "INFO"
      RDS_MASTER_SECRET_NAME = aws_secretsmanager_secret.app_secrets.name
      RDS_HOST               = aws_db_instance.main.address
      RDS_PORT               = tostring(aws_db_instance.main.port)
      RDS_DB_NAME            = aws_db_instance.main.db_name
    }
  }

  # Intentionally no dead_letter_config - this Lambda is invoked
  # synchronously by the operator (aws lambda invoke ... --invocation-type
  # RequestResponse). Sync invoke returns errors to the caller directly;
  # DLQ would not be exercised.

  depends_on = [
    aws_cloudwatch_log_group.db_bootstrap,
    aws_iam_role_policy.db_bootstrap_secrets,
    aws_iam_role_policy_attachment.db_bootstrap_vpc,
  ]

  tags = {
    Project     = var.project
    Environment = var.environment
    Lifecycle   = "one-time-bootstrap-delete-after-invocation"
  }
}
