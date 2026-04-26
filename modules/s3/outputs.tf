output "app_bucket_name" {
  description = "Nome do bucket S3 da aplicação"
  value       = aws_s3_bucket.app.id
}

output "app_bucket_arn" {
  description = "ARN do bucket S3 da aplicação"
  value       = aws_s3_bucket.app.arn
}

output "logs_bucket_name" {
  description = "Nome do bucket de logs de acesso"
  value       = aws_s3_bucket.logs.id
}

output "s3_kms_key_arn" {
  description = "ARN da chave KMS usada para criptografar os buckets"
  value       = aws_kms_key.s3.arn
}

output "tfstate_bucket_name" {
  description = "Nome do bucket de Terraform state (se criado)"
  value       = var.create_tfstate_bucket ? aws_s3_bucket.tfstate[0].id : ""
}

output "tfstate_dynamodb_table" {
  description = "Nome da tabela DynamoDB para lock do Terraform state (se criada)"
  value       = var.create_tfstate_bucket ? aws_dynamodb_table.tfstate_lock[0].name : ""
}
