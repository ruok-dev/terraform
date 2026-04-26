# terraform-aws-infra 🔐

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.6.0-623CE4?logo=terraform)](https://developer.hashicorp.com/terraform)
[![AWS Provider](https://img.shields.io/badge/AWS%20Provider-~%3E5.0-FF9900?logo=amazon-aws)](https://registry.terraform.io/providers/hashicorp/aws/latest)
[![Security: tfsec](https://img.shields.io/badge/Security-tfsec-3585C5)](https://aquasecurity.github.io/tfsec/)
[![Security: checkov](https://img.shields.io/badge/Compliance-checkov-7B42BC)](https://www.checkov.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Infraestrutura AWS **production-ready** com **foco total em segurança**. Arquitetura multi-ambiente (dev/staging/prod) usando Terraform modular com as melhores práticas do mercado e CIS Benchmark.

---

## 🏗️ Arquitetura

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────┐
│  Public Subnet (somente ALB)                    │
│  ┌───────────────────────────────────────────┐  │
│  │  Application Load Balancer (HTTPS only)   │  │
│  └───────────────────────┬───────────────────┘  │
└──────────────────────────│──────────────────────┘
                           │ (porta da app)
┌──────────────────────────▼──────────────────────┐
│  Private Subnet (EC2 / App)                     │
│  ┌───────────────────────────────────────────┐  │
│  │  Auto Scaling Group — EC2 (sem SSH)        │  │
│  │  Acesso via SSM Session Manager           │  │
│  └───────────────────────┬───────────────────┘  │
└──────────────────────────│──────────────────────┘
                           │ (porta do banco)
┌──────────────────────────▼──────────────────────┐
│  Database Subnet (isolada — sem rota de saída)  │
│  ┌───────────────────────────────────────────┐  │
│  │  RDS PostgreSQL (Multi-AZ em staging/prod)│  │
│  │  publicly_accessible = false              │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

---

## 📁 Estrutura

```
terraform-aws-infra/
│
├── environments/
│   ├── dev/           # Desenvolvimento — custo mínimo, NAT único
│   ├── staging/       # Homologação — espelha prod (Multi-AZ, GuardDuty)
│   └── prod/          # Produção — máxima segurança e disponibilidade
│
├── modules/
│   ├── vpc/           # VPC + subnets + NAT + VPC Flow Logs
│   ├── ec2/           # ASG + Launch Template + KMS EBS + IMDSv2
│   ├── rds/           # RDS + KMS + Secrets Manager + Monitoring
│   ├── s3/            # S3 hardened + KMS + versioning + logging
│   ├── iam/           # Roles com menor privilégio + OIDC CI/CD
│   ├── security/      # Security Groups + VPC Endpoints (SSM, S3, Secrets)
│   └── monitoring/    # CloudWatch + GuardDuty + SNS + Config + CIS alarms
│
├── .github/
│   ├── workflows/
│   │   └── terraform.yml  # CI/CD com OIDC (sem credenciais hardcoded)
│   └── CODEOWNERS         # Revisão obrigatória para módulos críticos
│
├── scripts/
│   ├── bootstrap.sh   # Cria S3 state bucket + DynamoDB (execute antes do init)
│   ├── deploy.sh      # Deploy com validação de segurança + plano local seguro
│   ├── destroy.sh     # Destroy com bloqueio em prod
│   └── validate.sh    # tfsec + checkov + terraform validate
│
├── policies/
│   ├── iam-policies/          # Políticas IAM com menor privilégio
│   └── security-policies/     # SCPs para AWS Organizations
│
├── .pre-commit-config.yaml    # Hooks de segurança pré-commit
├── SECURITY.md                # Política de divulgação de vulnerabilidades
└── Makefile                   # Comandos de produtividade
```

---

## 🔐 Segurança — Checklist

| # | Controle | Implementação |
|---|----------|---------------|
| 1 | Sem credenciais hardcoded | AWS CLI profiles + OIDC no CI/CD |
| 2 | Backend remoto seguro | S3 + DynamoDB lock + KMS encrypt |
| 3 | VPC segmentada | Public (LB) / Private (EC2) / DB (isolado) |
| 4 | Security Groups granulares | Sem `0.0.0.0/0` em portas críticas |
| 5 | EC2 sem SSH público | SSM Session Manager + VPC Endpoints |
| 6 | RDS sem IP público | `publicly_accessible = false` + subnet isolada |
| 7 | S3 hardened | Block public access + KMS + versioning + logging |
| 8 | IAM menor privilégio | Policies específicas por serviço, sem wildcards |
| 9 | Secrets Manager | Sem senhas no código — rotação automática |
| 10 | VPC Flow Logs | Auditoria de tráfego de rede |
| 11 | CloudTrail multi-region | Auditoria de todas as chamadas de API |
| 12 | GuardDuty | Detecção de ameaças e anomalias |
| 13 | IMDSv2 obrigatório | Proteção contra SSRF em EC2 |
| 14 | KMS em todos os recursos | EBS, RDS, S3, Secrets Manager, DynamoDB, CloudWatch |
| 15 | Alertas de segurança | Root usage, SG changes, IAM changes, logins falhos |
| 16 | UnauthorizedAPICalls | CIS Benchmark 3.1 — alerta de acesso negado |
| 17 | Pre-commit hooks | tfsec + checkov + detect-secrets local |
| 18 | CODEOWNERS | Revisão obrigatória em módulos críticos e prod |

---

## 🚀 Quick Start

### Pré-requisitos

```bash
# Terraform >= 1.6
sudo apt install terraform  # ou brew install terraform

# AWS CLI
sudo apt install awscli  # ou brew install awscli

# Ferramentas de segurança (recomendado)
brew install tfsec
pip install checkov

# Pre-commit hooks (recomendado)
pip install pre-commit
pre-commit install
```

### 1. Configure o perfil AWS CLI

```ini
# ~/.aws/config
[profile terraform-dev]
region = us-east-1
mfa_serial = arn:aws:iam::ACCOUNT_ID:mfa/seu-usuario   # opcional, recomendado

# ~/.aws/credentials
[terraform-dev]
aws_access_key_id = ...      # via IAM role ou credencial temporária
aws_secret_access_key = ...  # NUNCA commitar no git
```

### 2. Bootstrap — crie os recursos de state (apenas uma vez)

```bash
# Cria automaticamente o S3 bucket + DynamoDB para o ambiente desejado
bash scripts/bootstrap.sh dev YOUR_ACCOUNT_ID

# Para staging e prod:
bash scripts/bootstrap.sh staging YOUR_ACCOUNT_ID
bash scripts/bootstrap.sh prod YOUR_ACCOUNT_ID
```

### 3. Configure as variáveis

```bash
# Copie o exemplo (já está no .gitignore)
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars

# Edite com seus valores
vi environments/dev/terraform.tfvars
```

### 4. Atualize o backend

O script de bootstrap exibe o bloco exato para copiar no `backend.tf`:

```hcl
# environments/dev/backend.tf
terraform {
  backend "s3" {
    bucket         = "terraform-state-dev-YOUR_ACCOUNT_ID"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
    profile        = "terraform-dev"
  }
}
```

> ⚠️ **Não commite o backend.tf com valores reais** — use placeholders ou configure via CI/CD secrets.

### 5. Deploy

```bash
# Validação completa (recomendado antes de qualquer deploy)
make ci

# Init + Plan
make init ENV=dev
make plan ENV=dev

# Apply (pede confirmação)
make apply ENV=dev
```

---

## 🌎 Ambientes

| Ambiente | Propósito | NAT | Multi-AZ | GuardDuty | AWS Config |
|----------|-----------|-----|----------|-----------|-----------|
| **dev** | Desenvolvimento | 1 (econômico) | ❌ | Off | Off |
| **staging** | Homologação | 1 por AZ | ✅ | ✅ | Off |
| **prod** | Produção | 1 por AZ | ✅ | ✅ | ✅ |

---

## 🔄 CI/CD com GitHub Actions

O pipeline usa **OIDC** — sem access keys no repositório.

### Configurar OIDC na AWS

```bash
# Cria o OIDC Provider para GitHub (apenas uma vez por conta)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --profile terraform-prod
```

### Secrets necessários no repositório GitHub

```
AWS_ROLE_ARN_DEV      = arn:aws:iam::ACCOUNT_ID:role/myapp-dev-cicd-role
AWS_ROLE_ARN_STAGING  = arn:aws:iam::ACCOUNT_ID:role/myapp-staging-cicd-role
AWS_ROLE_ARN_PROD     = arn:aws:iam::ACCOUNT_ID:role/myapp-prod-cicd-role
```

### Fluxo de deploy

```
develop branch → validate → plan dev → apply dev (aprovação manual)
       │
       ▼
 PR → main branch → plan staging → apply staging (aprovação manual)
       │
       ▼
 Aprovação manual (2 reviewers) → plan prod → apply prod
```

---

## 🧪 Comandos úteis

```bash
make help              # Lista todos os comandos

make ci                # Pipeline completo local (fmt + creds + scan + validate)
make scan              # tfsec + checkov
make check-creds       # Verifica credenciais hardcoded

make init ENV=staging  # Init staging
make plan ENV=staging  # Plan staging
make apply ENV=staging # Apply staging

make output ENV=dev    # Mostra outputs
make state-list ENV=dev # Lista recursos no state

make clean             # Remove arquivos temporários
```

---

## 📊 Acesso à infraestrutura

### EC2 — sem SSH, use SSM

```bash
# Via AWS CLI (sem expor porta 22)
aws ssm start-session \
  --target i-xxxxxxxxxxxxxxxxx \
  --region us-east-1 \
  --profile terraform-dev
```

### Banco de dados — credenciais via Secrets Manager

```bash
# Busca credenciais (sem senha no terminal)
aws secretsmanager get-secret-value \
  --secret-id myapp-dev/rds/master-password \
  --region us-east-1 \
  --profile terraform-dev \
  --query SecretString \
  --output text | jq .
```

---

## ⚠️ Avisos importantes

- **Nunca** adicione `terraform.tfvars` ao git (está no `.gitignore`)
- **Nunca** use a conta root para operações rotineiras
- **Sempre** execute `make ci` antes de abrir um PR
- **Sempre** instale os pre-commit hooks: `pre-commit install`
- Em **produção**, o destroy exige `--force-prod` + dupla confirmação
- Habilite MFA em todas as contas IAM com acesso ao console
- O `.terraform.lock.hcl` **deve** ser commitado (garante versões exatas)

---

## 📚 Referências

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Security Best Practices](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [CIS AWS Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [tfsec](https://aquasecurity.github.io/tfsec/)
- [checkov](https://www.checkov.io/)
- [SSM Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [SECURITY.md](SECURITY.md) — Política de divulgação responsável
