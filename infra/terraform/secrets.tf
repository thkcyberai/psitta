# ── Psitta API Secrets ────────────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "${var.project}/prod/app-secrets"
  description = "Psitta production API keys and credentials"

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    POSTGRES_HOST     = aws_db_instance.main.address
    POSTGRES_PORT     = "5432"
    POSTGRES_DB       = "psitta"
    POSTGRES_USER     = "psitta"
    POSTGRES_PASSWORD = var.db_password

    COGNITO_USER_POOL_ID = aws_cognito_user_pool.main.id
    COGNITO_CLIENT_ID    = aws_cognito_user_pool_client.flutter_desktop.id
    COGNITO_REGION       = var.aws_region
    SECRET_KEY           = var.secret_key

    ELEVENLABS_API_KEY = var.elevenlabs_api_key
    AZURE_TTS_KEY      = var.azure_tts_key
    ANTHROPIC_API_KEY  = var.anthropic_api_key

    S3_ENDPOINT_URL = "https://s3.amazonaws.com"
    S3_REGION       = "us-east-1"
    S3_BUCKET_NAME  = "${var.project}-documents-prod"
  })
}

# ── Resend API Key (Welcome Email Lambda) ────────────────────────────────────
# Value populated manually via aws secretsmanager put-secret-value — never via
# Terraform. Keeps the API key out of Terraform state entirely. The Welcome
# Email Lambda's IAM role is scoped to read this secret only (least-privilege,
# distinct from the broader app_secrets blob above).
resource "aws_secretsmanager_secret" "resend_api_key" {
  name        = "${var.project}/prod/resend-api-key"
  description = "Resend API key for Welcome Email Lambda. Value populated manually via aws secretsmanager put-secret-value — never via Terraform."

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

output "resend_api_key_secret_arn" {
  description = "ARN of the resend-api-key secret (referenced by lambda_welcome_email.tf)"
  value       = aws_secretsmanager_secret.resend_api_key.arn
}
