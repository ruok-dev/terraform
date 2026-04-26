# environments/dev/variables.tf

# ── Globals ───────────────────────────────────────────────────────────────────
variable "project_name" {
  description = "Nome do projeto (usado em todos os recursos)"
  type        = string
}

variable "environment" {
  description = "Nome do ambiente"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Perfil AWS CLI (sem credenciais hardcoded)"
  type        = string
  default     = "default"
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
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Lista de AZs"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas (somente para Load Balancer)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas (EC2)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDRs das subnets do banco de dados (isoladas)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
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
  default     = "t3.small"
}

variable "asg_min_size" {
  description = "Mínimo de instâncias no ASG"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Máximo de instâncias no ASG"
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Capacidade desejada do ASG"
  type        = number
  default     = 1
}

# ── RDS ───────────────────────────────────────────────────────────────────────
variable "rds_instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Armazenamento inicial RDS (GB)"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Armazenamento máximo RDS com autoscaling (GB)"
  type        = number
  default     = 50
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "appdb"
}

# ── Monitoramento ─────────────────────────────────────────────────────────────
variable "alert_emails" {
  description = "E-mails para alertas de monitoramento e segurança"
  type        = list(string)
  default     = []
}

variable "enable_guardduty" {
  description = "Habilitar AWS GuardDuty"
  type        = bool
  default     = false # desabilitado em dev para economizar custo
}

# ── CI/CD ─────────────────────────────────────────────────────────────────────
variable "create_cicd_role" {
  description = "Criar IAM Role para GitHub Actions via OIDC"
  type        = bool
  default     = false
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
