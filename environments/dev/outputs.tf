# environments/dev/outputs.tf

output "vpc_id" {
  description = "ID da VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs das subnets públicas"
  value       = module.vpc.public_subnet_ids
}

output "app_bucket_name" {
  description = "Nome do bucket S3 da aplicação"
  value       = module.s3.app_bucket_name
}

output "db_secret_arn" {
  description = "ARN do secret com credenciais do banco (use Secrets Manager para acessar)"
  value       = module.rds.db_secret_arn
  sensitive   = true
}

output "asg_name" {
  description = "Nome do Auto Scaling Group"
  value       = module.ec2.asg_name
}

output "cloudwatch_dashboard" {
  description = "URL do CloudWatch Dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.monitoring.dashboard_name}"
}

output "cicd_role_arn" {
  description = "ARN da IAM Role para CI/CD (se criada)"
  value       = module.iam.cicd_role_arn
}

output "nat_gateway_ips" {
  description = "IPs dos NAT Gateways (adicione ao allowlist de serviços externos)"
  value       = module.vpc.nat_gateway_ips
}
