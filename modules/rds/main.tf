# modules/rds/main.tf
# RDS ultra protegido: sem IP público, multi-AZ, criptografia, sem senha hardcoded

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Senha armazenada no Secrets Manager (nunca hardcoded)
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.name}/rds/master-password"
  description             = "Senha master do RDS para ${var.name}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7
  kms_key_id              = var.kms_key_id != "" ? var.kms_key_id : null

  tags = {
    Name = "${var.name}-rds-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
  })

  depends_on = [aws_db_instance.this]
}

# ── KMS Key para RDS ──────────────────────────────────────────────────────────
resource "aws_kms_key" "rds" {
  description             = "${var.name} - RDS encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "${var.name}-rds-kms"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ── Parameter Group ───────────────────────────────────────────────────────────
resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-pg"
  family = var.parameter_group_family

  # SSL obrigatório para PostgreSQL
  dynamic "parameter" {
    for_each = var.engine == "postgres" ? [1] : []
    content {
      name  = "rds.force_ssl"
      value = "1"
    }
  }

  # Log de conexões lentas
  dynamic "parameter" {
    for_each = var.engine == "postgres" ? [1] : []
    content {
      name  = "log_min_duration_statement"
      value = "1000" # loga queries > 1 segundo
    }
  }

  tags = {
    Name = "${var.name}-parameter-group"
  }
}

# ── RDS Instance ──────────────────────────────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier = "${var.name}-${var.engine}"

  engine               = var.engine
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type         = "gp3"
  storage_encrypted    = true
  kms_key_id           = aws_kms_key.rds.arn

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  # ❌ Banco SEM IP público — princípio de zero trust
  publicly_accessible = false

  # Multi-AZ em produção
  multi_az = var.multi_az

  vpc_security_group_ids = [var.security_group_id]
  db_subnet_group_name   = var.db_subnet_group_name
  parameter_group_name   = aws_db_parameter_group.this.name

  # Backups
  backup_retention_period   = var.backup_retention_days
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot     = true
  delete_automated_backups  = var.environment != "prod"

  # Monitoramento avançado
  monitoring_interval = 60
  monitoring_role_arn = var.monitoring_role_arn

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = var.environment == "prod" ? 731 : 7
  performance_insights_kms_key_id       = aws_kms_key.rds.arn

  # Logs para CloudWatch
  enabled_cloudwatch_logs_exports = var.engine == "postgres" ? ["postgresql", "upgrade"] : ["error", "general", "slowquery"]

  # Proteção contra exclusão acidental em produção
  deletion_protection = var.environment == "prod"
  skip_final_snapshot = var.environment != "prod"
  # B4: timestamp() causava diff perpétuo a cada plan em prod (força replace acidental).
  # Usando sufixo estático baseado no nome — snapshot único por instância.
  final_snapshot_identifier = var.environment == "prod" ? "${var.name}-final-snapshot" : null

  auto_minor_version_upgrade = true
  apply_immediately          = var.environment != "prod"

  tags = {
    Name        = "${var.name}-rds"
    Environment = var.environment
  }

  lifecycle {
    # Previne substituição acidental ao mudar a senha (ela é gerenciada pelo Secrets Manager)
    ignore_changes = [password]
  }
}

# ── CloudWatch Alarms para RDS ────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.name}-rds-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU do RDS acima de 80% por 4 minutos"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.name}-rds-storage-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120 # 5 GB em bytes
  alarm_description   = "Armazenamento livre do RDS abaixo de 5 GB"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.name}-rds-connections-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.max_connections_threshold
  alarm_description   = "Número de conexões do RDS acima do limite"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }
}
