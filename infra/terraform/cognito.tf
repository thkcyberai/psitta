# ── Cognito User Pool ─────────────────────────────────────────────────────────
resource "aws_cognito_user_pool" "main" {
  name = "${var.project}-users"

  # ── Username & Sign-in ──────────────────────────────────────────────
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  username_configuration {
    case_sensitive = false
  }

  # ── Password Policy ─────────────────────────────────────────────────
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # ── Account Recovery ────────────────────────────────────────────────
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # ── Email Verification ───────────────────────────────────────────────
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Psitta — Verify your email"
    email_message        = "Your Psitta verification code is {####}"
  }

  # ── Standard Attributes ──────────────────────────────────────────────
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
    string_attribute_constraints {
      min_length = 5
      max_length = 254
    }
  }

  # ── MFA (optional now, enforce in M7) ───────────────────────────────
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  # ── Deletion Protection ──────────────────────────────────────────────
  deletion_protection = "ACTIVE"

  # ── Pre-Token-Generation v2 trigger (Item 11.4) ─────────────────────
  # Injects email claim into access tokens. V2_0 schema is required for
  # access-token modification — V1_0 only supports ID-token claims.
  lambda_config {
    pre_token_generation_config {
      lambda_arn     = aws_lambda_function.pre_token_gen.arn
      lambda_version = "V2_0"
    }
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── Cognito User Pool Domain (Hosted UI) ─────────────────────────────────────
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project}-auth-prod"
  user_pool_id = aws_cognito_user_pool.main.id
}

# ── Cognito App Client (Flutter Desktop — public PKCE client) ────────────────
resource "aws_cognito_user_pool_client" "flutter_desktop" {
  name         = "${var.project}-flutter-desktop"
  user_pool_id = aws_cognito_user_pool.main.id

  # Public client — no secret (PKCE handles security)
  generate_secret = false

  # ── Auth Flows ───────────────────────────────────────────────────────
  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]

  # ── OAuth / PKCE ─────────────────────────────────────────────────────
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  callback_urls = ["http://localhost:8080/callback"]
  logout_urls   = ["http://localhost:8080/logout"]

  supported_identity_providers = ["COGNITO"]

  # ── Token Validity ───────────────────────────────────────────────────
  access_token_validity  = 1  # hours
  id_token_validity      = 1  # hours
  refresh_token_validity = 30 # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # ── Security ─────────────────────────────────────────────────────────
  enable_token_revocation                       = true
  prevent_user_existence_errors                 = "ENABLED"
  enable_propagate_additional_user_context_data = false
}

# ── Outputs (used by secrets.tf and Flutter config) ──────────────────────────
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_client_id" {
  description = "Cognito App Client ID (Flutter desktop)"
  value       = aws_cognito_user_pool_client.flutter_desktop.id
}

output "cognito_domain" {
  description = "Cognito Hosted UI base URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.us-east-1.amazoncognito.com"
}

output "cognito_jwks_url" {
  description = "Cognito JWKS endpoint for backend JWT validation"
  value       = "https://cognito-idp.us-east-1.amazonaws.com/${aws_cognito_user_pool.main.id}/.well-known/jwks.json"
}

output "cognito_issuer" {
  description = "Cognito JWT issuer URL"
  value       = "https://cognito-idp.us-east-1.amazonaws.com/${aws_cognito_user_pool.main.id}"
}
