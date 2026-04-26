# global/main.tf
# Gerenciamento de recursos globais (OIDC Provider, IAM Roles de Admin)

provider "aws" {
  region = "us-east-1"
}

# ── OIDC Provider para GitHub Actions ─────────────────────────────────────────
# Permite que o GitHub Actions se autentique na AWS sem chaves de acesso estáticas
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # Digicert thumbprint
}

output "github_oidc_provider_arn" {
  description = "ARN do OIDC Provider para ser usado nos módulos IAM"
  value       = aws_iam_openid_connect_provider.github.arn
}
