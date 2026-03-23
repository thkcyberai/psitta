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
    DB_HOST            = aws_db_instance.main.address
    DB_PORT            = "5432"
    DB_NAME            = "psitta"
    DB_USER            = "psitta"
    DB_PASSWORD        = var.db_password
    ELEVENLABS_API_KEY = var.elevenlabs_api_key
    AZURE_TTS_KEY      = var.azure_tts_key
    ANTHROPIC_API_KEY  = var.anthropic_api_key

    S3_ENDPOINT_URL        = "https://s3.amazonaws.com"
    S3_REGION              = "us-east-1"
    S3_BUCKET_NAME         = "${var.project}-documents-prod"
    AWS_ACCESS_KEY_ID      = var.aws_access_key_id
    AWS_SECRET_ACCESS_KEY  = var.aws_secret_access_key
  })
}
