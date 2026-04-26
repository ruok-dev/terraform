variable "name" {
  description = "Prefixo de nomenclatura"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "app_bucket_name" {
  description = "Nome do bucket S3 da aplicação (para política granular)"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN da chave KMS (deixe vazio para usar a chave gerenciada pela AWS)"
  type        = string
  default     = ""
}

variable "create_cicd_role" {
  description = "Criar IAM Role para CI/CD via OIDC (GitHub Actions)"
  type        = bool
  default     = false
}

variable "github_oidc_provider_arn" {
  description = "ARN do OIDC Provider do GitHub (necessário se create_cicd_role = true)"
  type        = string
  default     = ""
}

variable "github_org" {
  description = "Organização/usuário do GitHub"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "Repositório do GitHub"
  type        = string
  default     = ""
}
