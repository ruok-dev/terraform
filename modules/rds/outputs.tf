output "db_instance_id" {
  description = "ID da instância RDS"
  value       = aws_db_instance.this.id
}

output "db_instance_address" {
  description = "Endpoint de conexão do banco"
  value       = aws_db_instance.this.address
  sensitive   = true
}

output "db_instance_port" {
  description = "Porta do banco de dados"
  value       = aws_db_instance.this.port
}

output "db_secret_arn" {
  description = "ARN do secret no Secrets Manager com as credenciais do banco"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "rds_kms_key_arn" {
  description = "ARN da chave KMS do RDS"
  value       = aws_kms_key.rds.arn
}
