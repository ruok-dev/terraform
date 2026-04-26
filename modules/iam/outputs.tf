output "ec2_instance_profile_name" {
  description = "Nome do Instance Profile para EC2"
  value       = aws_iam_instance_profile.ec2.name
}

output "ec2_role_arn" {
  description = "ARN da IAM Role da EC2"
  value       = aws_iam_role.ec2.arn
}

output "rds_monitoring_role_arn" {
  description = "ARN da IAM Role de monitoramento do RDS"
  value       = aws_iam_role.rds_monitoring.arn
}

output "cicd_role_arn" {
  description = "ARN da IAM Role para CI/CD"
  value       = var.create_cicd_role ? aws_iam_role.cicd[0].arn : ""
}
