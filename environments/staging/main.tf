# environments/staging/main.tf
# Orquestra todos os módulos para o ambiente STAGING (homologação)
# Espelha prod o mais próximo possível: Multi-AZ, GuardDuty ativo, mais instâncias

# ── Versions e Provider ───────────────────────────────────────────────────────
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
    }
  }
}

# ── Data sources ──────────────────────────────────────────────────────────────
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── CloudTrail (auditoria de todas as ações da conta) ────────────────────────
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${local.name_prefix}"
  retention_in_days = 90
}

resource "aws_iam_role" "cloudtrail" {
  name = "${local.name_prefix}-cloudtrail-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail" {
  name = "${local.name_prefix}-cloudtrail-policy"
  role = aws_iam_role.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

resource "aws_cloudtrail" "this" {
  name                          = "${local.name_prefix}-trail"
  s3_bucket_name                = module.s3.logs_bucket_name
  s3_key_prefix                 = "cloudtrail"
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail.arn
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = {
    Name = "${local.name_prefix}-cloudtrail"
  }

  depends_on = [module.s3]
}

# ── Módulo S3 ─────────────────────────────────────────────────────────────────
module "s3" {
  source = "../../modules/s3"

  name        = local.name_prefix
  environment = var.environment
  account_id  = local.account_id

  create_tfstate_bucket = false
}

# ── Módulo VPC ────────────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  name = local.name_prefix
  cidr = var.vpc_cidr
  azs  = var.availability_zones

  public_subnets   = var.public_subnet_cidrs
  private_subnets  = var.private_subnet_cidrs
  database_subnets = var.database_subnet_cidrs

  # Staging usa NAT por AZ para espelhar prod (detecta problemas de HA)
  single_nat_gateway       = false
  flow_logs_retention_days = 90
}

# ── Módulo Security ────────────────────────────────────────────────────────────
module "security" {
  source = "../../modules/security"

  name                    = local.name_prefix
  vpc_id                  = module.vpc.vpc_id
  vpc_cidr                = module.vpc.vpc_cidr
  region                  = local.region
  app_port                = var.app_port
  db_port                 = var.db_port
  private_subnet_ids      = module.vpc.private_subnet_ids
  private_route_table_ids = module.vpc.private_route_table_ids
}

# ── Módulo IAM ────────────────────────────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  name            = local.name_prefix
  region          = local.region
  account_id      = local.account_id
  app_bucket_name = module.s3.app_bucket_name
  kms_key_arn     = module.s3.s3_kms_key_arn

  create_cicd_role         = var.create_cicd_role
  github_oidc_provider_arn = var.github_oidc_provider_arn
  github_org               = var.github_org
  github_repo              = var.github_repo
}

# ── Módulo Monitoring ─────────────────────────────────────────────────────────
module "monitoring" {
  source = "../../modules/monitoring"

  name        = local.name_prefix
  environment = var.environment
  region      = local.region

  alert_emails              = var.alert_emails
  log_retention_days        = 90
  cloudtrail_log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  asg_name                  = module.ec2.asg_name
  rds_identifier            = "${local.name_prefix}-postgres"
  kms_key_arn               = module.s3.s3_kms_key_arn

  # Staging tem GuardDuty ativo (espelha prod)
  enable_guardduty  = true
  enable_aws_config = false

  depends_on = [module.ec2, module.rds]
}

# ── Módulo EC2 ────────────────────────────────────────────────────────────────
module "ec2" {
  source = "../../modules/ec2"

  name        = local.name_prefix
  environment = var.environment
  region      = local.region

  instance_type    = var.ec2_instance_type
  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  private_subnet_ids    = module.vpc.private_subnet_ids
  security_group_ids    = [module.security.app_sg_id]
  instance_profile_name = module.iam.ec2_instance_profile_name
  target_group_arns     = []

  cloudwatch_log_group = module.monitoring.app_log_group_name

  depends_on = [module.vpc, module.security, module.iam, module.monitoring]
}

# ── Módulo RDS ────────────────────────────────────────────────────────────────
module "rds" {
  source = "../../modules/rds"

  name        = local.name_prefix
  environment = var.environment

  engine                 = "postgres"
  engine_version         = "15.4"
  parameter_group_family = "postgres15"
  instance_class         = var.rds_instance_class
  allocated_storage      = var.rds_allocated_storage
  max_allocated_storage  = var.rds_max_allocated_storage

  db_name     = var.db_name
  db_username = var.db_username
  # Staging com Multi-AZ para espelhar prod e detectar problemas de failover
  multi_az = true

  security_group_id    = module.security.rds_sg_id
  db_subnet_group_name = module.vpc.db_subnet_group_name
  monitoring_role_arn  = module.iam.rds_monitoring_role_arn

  backup_retention_days     = 7
  alarm_actions             = [module.monitoring.sns_topic_arn]
  max_connections_threshold = 100

  depends_on = [module.vpc, module.security, module.iam]
}
