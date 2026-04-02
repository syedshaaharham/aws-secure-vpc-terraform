# KMS Key
resource "aws_kms_key" "vault_key" {
  description             = "KMS key for Secure Document Vault"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "vault_alias" {
  name          = "alias/secure-doc-vault-key"
  target_key_id = aws_kms_key.vault_key.key_id
}

# S3 Bucket (Private)
resource "aws_s3_bucket" "vault_files" {
  bucket = "secure-doc-vault-${var.your_account_id}-files"
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.vault_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.vault_files.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.vault_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.vault_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table
resource "aws_dynamodb_table" "documents" {
  name         = "secure-doc-vault-documents"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "fileId"

  attribute {
    name = "fileId"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  global_secondary_index {
    name            = "UserIdIndex"
    hash_key        = "userId"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expiryDate"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.vault_key.arn
  }
}

# ==================== Cognito User Pool ====================
resource "aws_cognito_user_pool" "vault_users" {
  name = "${var.project_name}-users"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = {
    Name        = "${var.project_name}-cognito"
    Environment = var.environment
  }
}

resource "aws_cognito_user_pool_client" "vault_client" {
  name                                 = "${var.project_name}-client"
  user_pool_id                         = aws_cognito_user_pool.vault_users.id
  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true

  allowed_oauth_flows  = ["code", "implicit"]
  allowed_oauth_scopes = ["email", "openid", "profile"]

  callback_urls = ["http://localhost:3000"]   # Update later with your frontend URL
  logout_urls   = ["http://localhost:3000"]

  prevent_user_existence_errors = "ENABLED"   # Security best practice
}