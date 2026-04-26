variable "name" {
  description = "Prefixo de nomenclatura"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR da VPC (usado para regras de ingress interno)"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "app_port" {
  description = "Porta da aplicação nas instâncias EC2"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Porta do banco de dados"
  type        = number
  default     = 5432
}

variable "private_subnet_ids" {
  description = "IDs das subnets privadas (para VPC Endpoints)"
  type        = list(string)
}

variable "private_route_table_ids" {
  description = "IDs das route tables privadas (para S3 Gateway Endpoint)"
  type        = list(string)
}
