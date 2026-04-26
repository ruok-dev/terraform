variable "name" {
  description = "Prefixo de nomenclatura para todos os recursos da VPC"
  type        = string
}

variable "cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "O valor de cidr deve ser um CIDR válido."
  }
}

variable "azs" {
  description = "Lista de Availability Zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "CIDRs das subnets públicas (uso exclusivo do Load Balancer)"
  type        = list(string)
  default     = []
}

variable "private_subnets" {
  description = "CIDRs das subnets privadas (EC2)"
  type        = list(string)
  default     = []
}

variable "database_subnets" {
  description = "CIDRs das subnets de banco de dados (isoladas, sem rota de saída)"
  type        = list(string)
  default     = []
}

variable "single_nat_gateway" {
  description = "Usar um único NAT Gateway (true em dev/staging para economizar custo)"
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "Dias de retenção dos VPC Flow Logs no CloudWatch"
  type        = number
  default     = 90
}
