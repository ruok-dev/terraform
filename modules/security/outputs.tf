output "alb_sg_id" {
  description = "ID do Security Group do ALB"
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "ID do Security Group da aplicação (EC2)"
  value       = aws_security_group.app.id
}

output "rds_sg_id" {
  description = "ID do Security Group do RDS"
  value       = aws_security_group.rds.id
}

output "vpc_endpoints_sg_id" {
  description = "ID do Security Group dos VPC Endpoints"
  value       = aws_security_group.vpc_endpoints.id
}
