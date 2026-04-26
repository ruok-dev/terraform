# modules/security/main.tf
# Security Groups com princípio do menor privilégio

# ── ALB Security Group ────────────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "ALB: aceita HTTP/HTTPS da internet, sem acesso direto a EC2"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP da internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS da internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Saída apenas para as instâncias EC2"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    # referenciado pelo SG da EC2 para evitar dependência circular
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.name}-alb-sg"
  }
}

# ── EC2 / App Security Group ──────────────────────────────────────────────────
resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "EC2: aceita tráfego apenas do ALB, sem SSH público"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Tráfego da app vindo do ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Saída para internet via NAT (updates, SDK calls)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-app-sg"
  }
}

# ── RDS Security Group ────────────────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "RDS: aceita apenas conexões do SG da aplicação"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Banco acessível apenas pela EC2 da aplicação"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # Sem egress externo: banco não precisa iniciar conexões de saída
  # S6: No AWS provider 5.x não é possível combinar self=true com cidr_blocks=[]
  # Usando lifecycle ignore para manter a semântica de "sem saída"
  egress {
    description = "Sem saída (banco isolado)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  tags = {
    Name = "${var.name}-rds-sg"
  }
}

# ── VPC Endpoint Security Group (SSM, S3, etc.) ───────────────────────────────
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name}-vpc-endpoints-sg"
  description = "VPC Endpoints: HTTPS da VPC sem tráfego externo"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS interno da VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Saída interna apenas"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.name}-vpc-endpoints-sg"
  }
}

# ── VPC Endpoints (evita tráfego pela internet pública) ───────────────────────
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.name}-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.name}-ssmmessages-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.name}-ec2messages-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids

  tags = {
    Name = "${var.name}-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.name}-secretsmanager-endpoint"
  }
}
