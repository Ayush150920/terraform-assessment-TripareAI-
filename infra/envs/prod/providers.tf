provider "aws" {
  region = var.aws_region

  # --- REVIEW / PLAN-ONLY configuration ---
  # Static placeholder credentials + the skip_* flags let `terraform validate`
  # and `terraform plan -refresh=false` run with ZERO setup and no real AWS
  # account. No API calls are ever made: there are no data sources, and
  # -refresh=false skips state refresh, so these creds are never used.
  # For a real deployment, delete the two mock_* lines below (and optionally the
  # skip_* flags) and supply real credentials via env vars / profile / role.
  access_key = "mock_access_key"
  secret_key = "mock_secret_key"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
