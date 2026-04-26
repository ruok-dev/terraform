variable "name" {
  description = "Prefixo de nomenclatura"
  type        = string
}

variable "environment" {
  description = "Nome do ambiente (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "ami_id" {
  description = "ID da AMI (deixe vazio para usar Amazon Linux 2023 mais recente)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Tipo de instância EC2"
  type        = string
  default     = "t3.small"
}

variable "min_size" {
  description = "Quantidade mínima de instâncias no ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Quantidade máxima de instâncias no ASG"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Quantidade desejada de instâncias no ASG"
  type        = number
  default     = 2
}

variable "private_subnet_ids" {
  description = "IDs das subnets privadas onde as instâncias serão lançadas"
  type        = list(string)
}

variable "security_group_ids" {
  description = "IDs dos Security Groups para as instâncias"
  type        = list(string)
}

variable "instance_profile_name" {
  description = "Nome do IAM Instance Profile"
  type        = string
}

variable "target_group_arns" {
  description = "ARNs dos Target Groups do ALB"
  type        = list(string)
  default     = []
}

variable "root_volume_size" {
  description = "Tamanho do volume root em GB"
  type        = number
  default     = 20
}

variable "cloudwatch_log_group" {
  description = "Nome do Log Group no CloudWatch"
  type        = string
}
