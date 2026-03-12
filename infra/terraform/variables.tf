variable "aws_region" {
  default = "us-east-1"
}

variable "project" {
  default = "psitta"
}

variable "environment" {
  default = "prod"
}

variable "db_password" {
  description = "RDS master password"
  sensitive   = true
}

variable "elevenlabs_api_key" {
  description = "ElevenLabs API key"
  sensitive   = true
}

variable "azure_tts_key" {
  description = "Azure Cognitive TTS key"
  sensitive   = true
}

variable "anthropic_api_key" {
  description = "Anthropic API key"
  sensitive   = true
}
