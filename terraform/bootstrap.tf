# ─────────────────────────────────────────────────────────────
# BOOTSTRAP — Run this ONCE before enabling the S3 backend.
# Steps:
#   1. Comment out the backend "s3" block in providers.tf
#   2. terraform init && terraform apply -target=aws_s3_bucket.tfstate -target=aws_dynamodb_table.tflock
#   3. Uncomment the backend block in providers.tf
#   4. terraform init -migrate-state
# ─────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "tfstate" {
  bucket        = "devsecops-poc-tfstate"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tflock" {
  name         = "devsecops-poc-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
