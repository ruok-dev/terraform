output "asg_name" {
  description = "Nome do Auto Scaling Group"
  value       = aws_autoscaling_group.this.name
}

output "launch_template_id" {
  description = "ID do Launch Template"
  value       = aws_launch_template.this.id
}

output "ebs_kms_key_arn" {
  description = "ARN da chave KMS usada para criptografar os volumes EBS"
  value       = aws_kms_key.ebs.arn
}
