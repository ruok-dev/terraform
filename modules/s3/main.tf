# modules/s3/main.tf
# S3 Hardened: block public access, criptografia KMS, versionamento, logging

# ── KMS Key para S3 ───────────────────────────────────────────────────────────
resource "aws_kms_key" "s3" {
  description             = "${var.name} - S3 encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.name}-s3-kms"
  }
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.name}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

# ── Bucket de Logs de Acesso (audit trail) ────────────────────────────────────
resource "aws_s3_bucket" "logs" {
  bucket        = "${var.name}-access-logs-${var.account_id}"
  force_destroy = var.environment != "prod"

  tags = {
    Name    = "${var.name}-access-logs"
    Purpose = "s3-access-logging"
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# Política que permite ao S3 escrever logs de acesso
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  # B5: depends_on explícito para garantir que o bucket app exista antes de referenciá-lo
  depends_on = [aws_s3_bucket.app, aws_s3_bucket_public_access_block.logs]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ServerAccessLogsPolicy"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/*"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.app.arn
          }
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
        }
      }
    ]
  })
}

# ── Bucket Principal da Aplicação ─────────────────────────────────────────────
resource "aws_s3_bucket" "app" {
  bucket        = "${var.name}-app-${var.account_id}"
  force_destroy = var.environment != "prod"

  tags = {
    Name        = "${var.name}-app-bucket"
    Environment = var.environment
  }
}

# 🚫 Block ALL public access
resource "aws_s3_bucket_public_access_block" "app" {
  bucket                  = aws_s3_bucket.app.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 🔐 Criptografia KMS (não apenas AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true # reduz custo de chamadas KMS
  }
}

# 📜 Versionamento ativado
resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 🔍 Logging de acesso
resource "aws_s3_bucket_logging" "app" {
  bucket        = aws_s3_bucket.app.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "app-bucket/"

  depends_on = [aws_s3_bucket_policy.logs]
}

# ♻️ Lifecycle: limpa versões antigas e objetos expirados
resource "aws_s3_bucket_lifecycle_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# 🔒 Bucket Policy: força HTTPS e bloqueia acesso sem criptografia
resource "aws_s3_bucket_policy" "app" {
  bucket = aws_s3_bucket.app.id

  depends_on = [aws_s3_bucket_public_access_block.app]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.app.arn,
          "${aws_s3_bucket.app.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.app.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# ── Bucket para Terraform State (se solicitado) ───────────────────────────────
resource "aws_s3_bucket" "tfstate" {
  count         = var.create_tfstate_bucket ? 1 : 0
  bucket        = "${var.name}-tfstate-${var.account_id}"
  force_destroy = false # NUNCA destruir state por acidente

  tags = {
    Name    = "${var.name}-tfstate"
    Purpose = "terraform-state"
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  count                   = var.create_tfstate_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.tfstate[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tfstate" {
  count  = var.create_tfstate_bucket ? 1 : 0
  bucket = aws_s3_bucket.tfstate[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  count  = var.create_tfstate_bucket ? 1 : 0
  bucket = aws_s3_bucket.tfstate[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  count  = var.create_tfstate_bucket ? 1 : 0
  bucket = aws_s3_bucket.tfstate[0].id

  depends_on = [aws_s3_bucket_public_access_block.tfstate]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate[0].arn,
          "${aws_s3_bucket.tfstate[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# DynamoDB para lock do Terraform State
resource "aws_dynamodb_table" "tfstate_lock" {
  count        = var.create_tfstate_bucket ? 1 : 0
  name         = "${var.name}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.s3.arn
  }

  tags = {
    Name    = "${var.name}-tfstate-lock"
    Purpose = "terraform-state-lock"
  }
}
