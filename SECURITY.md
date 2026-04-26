# Security Policy — terraform-aws-infra

## 🔐 Relatando Vulnerabilidades

Se você encontrou uma vulnerabilidade de segurança neste projeto, **NÃO abra uma issue pública**.

Entre em contato de forma privada pelo e-mail listado no perfil do GitHub ou por meio do botão **"Report a vulnerability"** na aba Security deste repositório.

Por favor, inclua:
- Descrição detalhada da vulnerabilidade
- Passos para reproduzir
- Impacto potencial
- Sugestão de correção (se houver)

Responderemos em até **48 horas** e trabalharemos para corrigir o problema o mais rápido possível.

---

## 🚫 Dados Sensíveis — O que NUNCA deve ser commitado

Este repositório contém apenas código de infraestrutura (IaC). Os seguintes itens **JAMAIS** devem estar no histórico do Git:

| Tipo | Exemplos | Por quê é crítico |
|------|---------|-------------------|
| **Credenciais AWS** | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | Acesso total à conta AWS |
| **Terraform State** | `*.tfstate`, `*.tfstate.backup` | Contém todos os segredos e IDs de recursos |
| **Variáveis reais** | `terraform.tfvars` (sem `.example`) | Pode conter IPs, senhas, ARNs reais |
| **Chaves SSH/TLS** | `*.pem`, `*.key`, `*_rsa` | Acesso direto a servidores |
| **Planos de execução** | `*.tfplan`, arquivos em `.plans/` | Contém estado atual da infraestrutura |
| **Account IDs reais** | Em qualquer arquivo `.tf` ou script | Facilita targeting de ataques |
| **Tokens de API** | GitHub PAT, tokens de terceiros | Acesso a serviços externos |

### Como verificar antes de fazer push

```bash
# Verifique arquivos staged
git status

# Verifique credenciais hardcoded
make check-creds

# Verifique secrets nos arquivos
git diff --cached | grep -E "(AKIA[A-Z0-9]{16}|password\s*=|secret\s*=)"

# Scan completo
make ci
```

---

## 🛡️ Controles de Segurança Implementados

| Controle | Implementação |
|----------|---------------|
| Sem credenciais hardcoded | AWS CLI profiles + GitHub Actions OIDC |
| Backend remoto seguro | S3 + DynamoDB + KMS encryption |
| Scan automático | tfsec + checkov no CI/CD |
| Auditoria de commits | Check de credenciais no pipeline |
| Secrets em runtime | AWS Secrets Manager (nunca no código) |
| VPC isolada | EC2 e RDS sem IP público |
| KMS em todos os recursos | EBS, RDS, S3, DynamoDB, CloudWatch |

---

## 📋 Histórico de Segurança

Divulgações públicas de vulnerabilidades corrigidas serão listadas aqui após a resolução.

| Data | CVE/Issue | Severidade | Status |
|------|-----------|-----------|--------|
| — | — | — | — |

---

## 🔗 Referências

- [AWS Security Best Practices](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [Terraform Security Best Practices](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices/part3.2)
- [CIS AWS Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [tfsec Rules](https://aquasecurity.github.io/tfsec/latest/checks/aws/)
