variable "name" {
  description = "Prefixo de nomenclatura"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID (usado para nomear buckets de forma única)"
  type        = string
}

variable "create_tfstate_bucket" {
  description = "Criar bucket S3 e tabela DynamoDB para Terraform state"
  type        = bool
  default     = false
}
