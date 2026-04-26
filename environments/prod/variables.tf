# environments/prod/variables.tf

# ── Globals ───────────────────────────────────────────────────────────────────
variable "project_name" {
  description = "Nome do projeto (usado em todos os recursos)"
  type        = string
}

variable "environment" {
  description = "Nome do ambiente"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Perfil AWS CLI (sem credenciais hardcoded)"
  type        = string
  default     = "terraform-prod"
}

variable "owner" {
  description = "Time/pessoa responsável pelos recursos"
  type        = string
}

variable "cost_center" {
  description = "Centro de custo para billing"
  type        = string
  default     = "engineering"
}

# ── Networking ────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.2.0.0/16"
}

variable "availability_zones" {
  description = "Lista de AZs (mínimo 3 em prod para alta disponibilidade)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas (somente para Load Balancer)"
  type        = list(string)
  default     = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas (EC2)"
  type        = list(string)
  default     = ["10.2.10.0/24", "10.2.11.0/24", "10.2.12.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDRs das subnets do banco de dados (isoladas)"
  type        = list(string)
  default     = ["10.2.20.0/24", "10.2.21.0/24", "10.2.22.0/24"]
}

# ── Aplicação ─────────────────────────────────────────────────────────────────
variable "app_port" {
  description = "Porta da aplicação"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Porta do banco de dados"
  type        = number
  default     = 5432
}

# ── EC2 ───────────────────────────────────────────────────────────────────────
variable "ec2_instance_type" {
  description = "Tipo de instância EC2"
  type        = string
  default     = "t3.large"

  validation {
    condition     = !contains(["t3.nano", "t3.micro", "t3.small"], var.ec2_instance_type)
    error_message = "Em produção use instâncias t3.medium ou maiores para garantir performance."
  }
}

variable "asg_min_size" {
  description = "Mínimo de instâncias no ASG (mínimo 2 em prod)"
  type        = number
  default     = 2

  validation {
    condition     = var.asg_min_size >= 2
    error_message = "Em produção o ASG deve ter no mínimo 2 instâncias para alta disponibilidade."
  }
}

variable "asg_max_size" {
  description = "Máximo de instâncias no ASG"
  type        = number
  default     = 6
}

variable "asg_desired_capacity" {
  description = "Capacidade desejada do ASG"
  type        = number
  default     = 3
}

# ── RDS ───────────────────────────────────────────────────────────────────────
variable "rds_instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.medium"
}

variable "rds_allocated_storage" {
  description = "Armazenamento inicial RDS (GB)"
  type        = number
  default     = 100
}

variable "rds_max_allocated_storage" {
  description = "Armazenamento máximo RDS com autoscaling (GB)"
  type        = number
  default     = 500
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Username master do banco (não use valores previsíveis)"
  type        = string
  # Sem default — OBRIGATÓRIO definir no tfvars
}

# ── Monitoramento ─────────────────────────────────────────────────────────────
variable "alert_emails" {
  description = "E-mails para alertas críticos de produção"
  type        = list(string)

  validation {
    condition     = length(var.alert_emails) > 0
    error_message = "Em produção é obrigatório configurar pelo menos um e-mail para alertas."
  }
}

variable "enable_aws_config" {
  description = "Habilitar AWS Config (auditoria de conformidade) — recomendado em prod"
  type        = bool
  default     = true
}

# ── CI/CD ─────────────────────────────────────────────────────────────────────
variable "create_cicd_role" {
  description = "Criar IAM Role para GitHub Actions via OIDC"
  type        = bool
  default     = true
}

variable "github_oidc_provider_arn" {
  description = "ARN do OIDC Provider do GitHub"
  type        = string
  default     = ""
}

variable "github_org" {
  description = "Organização do GitHub"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "Repositório do GitHub"
  type        = string
  default     = ""
}
