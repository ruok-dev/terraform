# modules/monitoring/main.tf
# Monitoramento centralizado: CloudWatch, SNS, alarmes de segurança

# ── SNS Topic para alertas ────────────────────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name              = "${var.name}-alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name = "${var.name}-alerts"
  }
}

resource "aws_sns_topic_subscription" "email" {
  count     = length(var.alert_emails)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_emails[count.index]
}

# ── Log Group central da aplicação ───────────────────────────────────────────
resource "aws_cloudwatch_log_group" "app" {
  name              = "/app/${var.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn != "" ? var.kms_key_arn : null

  tags = {
    Name = "${var.name}-app-logs"
  }
}

resource "aws_cloudwatch_log_group" "alb" {
  name              = "/aws/alb/${var.name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.name}-alb-logs"
  }
}

# ── Alarme: tentativas de login com falha (CloudTrail) ───────────────────────
resource "aws_cloudwatch_log_metric_filter" "failed_console_logins" {
  name           = "${var.name}-failed-console-logins"
  pattern        = "{ ($.eventName = ConsoleLogin) && ($.errorMessage = \"Failed authentication\") }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name          = "FailedConsoleLogins"
    namespace     = "${var.name}/Security"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "failed_console_logins" {
  alarm_name          = "${var.name}-failed-console-logins"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedConsoleLogins"
  namespace           = "${var.name}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "ALERTA DE SEGURANÇA: 3+ tentativas de login no console com falha em 5 minutos"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

# ── Alarme: mudanças em Security Groups ──────────────────────────────────────
resource "aws_cloudwatch_log_metric_filter" "sg_changes" {
  name           = "${var.name}-sg-changes"
  pattern        = "{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name          = "SecurityGroupChanges"
    namespace     = "${var.name}/Security"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "sg_changes" {
  alarm_name          = "${var.name}-security-group-changes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "SecurityGroupChanges"
  namespace           = "${var.name}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "ALERTA: Modificação em Security Group detectada"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

# ── Alarme: mudanças em IAM ──────────────────────────────────────────────────
resource "aws_cloudwatch_log_metric_filter" "iam_changes" {
  name           = "${var.name}-iam-changes"
  pattern        = "{($.eventSource = iam.amazonaws.com) && (($.eventName = AddUserToGroup) || ($.eventName = AttachGroupPolicy) || ($.eventName = AttachRolePolicy) || ($.eventName = AttachUserPolicy) || ($.eventName = CreateGroup) || ($.eventName = CreatePolicy) || ($.eventName = CreateRole) || ($.eventName = CreateUser) || ($.eventName = DeleteGroupPolicy) || ($.eventName = DeleteRolePolicy) || ($.eventName = DeleteUserPolicy) || ($.eventName = DetachGroupPolicy) || ($.eventName = DetachRolePolicy) || ($.eventName = DetachUserPolicy))}"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name          = "IAMPolicyChanges"
    namespace     = "${var.name}/Security"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "iam_changes" {
  alarm_name          = "${var.name}-iam-changes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "IAMPolicyChanges"
  namespace           = "${var.name}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "ALERTA: Modificação em política IAM detectada"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

# ── Alarme: root account usage ────────────────────────────────────────────────
resource "aws_cloudwatch_log_metric_filter" "root_usage" {
  name           = "${var.name}-root-usage"
  pattern        = "{$.userIdentity.type = Root && $.userIdentity.invokedBy NOT EXISTS && $.eventType != AwsServiceEvent}"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name          = "RootAccountUsage"
    namespace     = "${var.name}/Security"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_usage" {
  alarm_name          = "${var.name}-root-account-usage"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "${var.name}/Security"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "CRÍTICO: Conta root foi utilizada — investigue imediatamente"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

# ── Alarme: chamadas de API não autorizadas (CIS Benchmark 3.1) ─────────────────
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "${var.name}-unauthorized-api-calls"
  pattern        = "{($.errorCode = \"*UnauthorizedAccess\") || ($.errorCode = \"AccessDenied\")}"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name          = "UnauthorizedAPICalls"
    namespace     = "${var.name}/Security"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "${var.name}-unauthorized-api-calls"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "${var.name}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "ALERTA CIS 3.1: Chamadas de API não autorizadas/negadas detectadas"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

# ── Dashboard CloudWatch ──────────────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "## ${upper(var.name)} — Visão Geral do Ambiente ${upper(var.environment)}"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          title   = "CPU da Aplicação (ASG)"
          metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name]]
          period  = 60
          stat    = "Average"
          view    = "timeSeries"
          region  = var.region
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          title   = "CPU do RDS"
          metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_identifier]]
          period  = 60
          stat    = "Average"
          view    = "timeSeries"
          region  = var.region
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          title = "Alertas de Segurança (últimas 24h)"
          metrics = [
            ["${var.name}/Security", "FailedConsoleLogins"],
            ["${var.name}/Security", "SecurityGroupChanges"],
            ["${var.name}/Security", "IAMPolicyChanges"],
            ["${var.name}/Security", "RootAccountUsage"]
          ]
          period = 86400
          stat   = "Sum"
          view   = "singleValue"
          region = var.region
        }
      }
    ]
  })
}

# ── GuardDuty ─────────────────────────────────────────────────────────────────
resource "aws_guardduty_detector" "this" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = false
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = {
    Name = "${var.name}-guardduty"
  }
}

# ── AWS Config (auditoria de conformidade) ────────────────────────────────────
resource "aws_config_configuration_recorder" "this" {
  count    = var.enable_aws_config ? 1 : 0
  name     = "${var.name}-config-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_iam_role" "config" {
  count = var.enable_aws_config ? 1 : 0
  name  = "${var.name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_aws_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  # B6: ARN correto — era AWS_ConfigRole (com underscore), o correto é AWSConfigRole
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

resource "aws_config_delivery_channel" "this" {
  count          = var.enable_aws_config ? 1 : 0
  name           = "${var.name}-config-channel"
  s3_bucket_name = var.config_s3_bucket

  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  count      = var.enable_aws_config ? 1 : 0
  name       = aws_config_configuration_recorder.this[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}
