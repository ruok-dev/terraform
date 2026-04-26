variable "name" {
  description = "Prefixo de nomenclatura"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "engine" {
  description = "Engine do banco (postgres, mysql)"
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "mysql"], var.engine)
    error_message = "Engine deve ser 'postgres' ou 'mysql'."
  }
}

variable "engine_version" {
  description = "Versão do engine"
  type        = string
  default     = "15.4"
}

variable "parameter_group_family" {
  description = "Família do Parameter Group"
  type        = string
  default     = "postgres15"
}

variable "instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Armazenamento inicial em GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Armazenamento máximo para autoscaling em GB"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
}

variable "db_username" {
  description = "Username master do banco (não use valores previsíveis como 'admin' ou 'root')"
  type        = string
  # S3: Sem default — o usuário é forçado a definir um valor explícito no tfvars
}


variable "security_group_id" {
  description = "ID do Security Group do RDS"
  type        = string
}

variable "db_subnet_group_name" {
  description = "Nome do DB Subnet Group"
  type        = string
}

variable "multi_az" {
  description = "Habilitar Multi-AZ (recomendado para prod)"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Dias de retenção de backups automáticos"
  type        = number
  default     = 7
}

variable "monitoring_role_arn" {
  description = "ARN da IAM Role para Enhanced Monitoring"
  type        = string
}

variable "kms_key_id" {
  description = "ID da chave KMS para o Secrets Manager (deixe vazio para usar chave padrão)"
  type        = string
  default     = ""
}

variable "alarm_actions" {
  description = "Lista de ARNs para ações de alarme (ex: SNS topic)"
  type        = list(string)
  default     = []
}

variable "max_connections_threshold" {
  description = "Limite de conexões para disparo de alarme"
  type        = number
  default     = 100
}
