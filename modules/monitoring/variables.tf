variable "name" {
  description = "Prefixo de nomenclatura"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "alert_emails" {
  description = "Lista de e-mails para receber alertas via SNS"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Dias de retenção dos logs no CloudWatch"
  type        = number
  default     = 90
}

variable "kms_key_arn" {
  description = "ARN da chave KMS para criptografia dos logs"
  type        = string
  default     = ""
}

variable "cloudtrail_log_group_name" {
  description = "Nome do Log Group do CloudTrail (para filtros de segurança)"
  type        = string
}

variable "asg_name" {
  description = "Nome do Auto Scaling Group (para dashboard)"
  type        = string
}

variable "rds_identifier" {
  description = "Identifier da instância RDS (para dashboard)"
  type        = string
}

variable "enable_guardduty" {
  description = "Habilitar AWS GuardDuty (detecção de ameaças)"
  type        = bool
  default     = true
}

variable "enable_aws_config" {
  description = "Habilitar AWS Config (auditoria de conformidade)"
  type        = bool
  default     = false
}

variable "config_s3_bucket" {
  description = "Nome do bucket S3 para entrega do AWS Config (necessário se enable_aws_config = true)"
  type        = string
  default     = ""
}
