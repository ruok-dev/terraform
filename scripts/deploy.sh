#!/usr/bin/env bash
# scripts/deploy.sh
# Deploy seguro com validação obrigatória antes de aplicar

set -euo pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Validação de argumentos ───────────────────────────────────────────────────
usage() {
  echo "Uso: $0 <ambiente>"
  echo "Ambientes: dev | staging | prod"
  exit 1
}

[[ $# -lt 1 ]] && usage
ENV="$1"

case "$ENV" in
  dev|staging|prod) ;;
  *) log_error "Ambiente inválido: $ENV"; usage ;;
esac

ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/environments/$ENV"

[[ ! -d "$ENV_DIR" ]] && { log_error "Diretório não encontrado: $ENV_DIR"; exit 1; }

# ── Verificações de segurança pré-deploy ──────────────────────────────────────
log_info "Verificando pré-requisitos..."

command -v terraform >/dev/null 2>&1 || { log_error "terraform não encontrado no PATH"; exit 1; }
command -v aws >/dev/null 2>&1       || { log_error "aws CLI não encontrado no PATH"; exit 1; }

# Verifica que não há credenciais hardcoded em nenhum arquivo .tf
log_info "Verificando credenciais hardcoded nos arquivos .tf..."
if grep -r --include="*.tf" -E "(aws_access_key_id|aws_secret_access_key|password\s*=\s*\"[^\"]{8,}\")" "$ENV_DIR" 2>/dev/null | grep -v "var\." | grep -v "#"; then
  log_error "BLOQUEADO: Credenciais hardcoded detectadas! Corrija antes de continuar."
  exit 1
fi
log_success "Nenhuma credencial hardcoded encontrada."

# Verificação extra em prod: requer confirmação manual
if [[ "$ENV" == "prod" ]]; then
  log_warn "⚠️  ATENÇÃO: Você está fazendo deploy em PRODUÇÃO!"
  read -rp "Digite 'PRODUÇÃO' para confirmar: " CONFIRM
  [[ "$CONFIRM" != "PRODUÇÃO" ]] && { log_error "Confirmação inválida. Deploy cancelado."; exit 1; }
fi

# ── Scan de segurança (tfsec / checkov) ───────────────────────────────────────
if command -v tfsec >/dev/null 2>&1; then
  log_info "Executando tfsec..."
  tfsec "$ENV_DIR" --minimum-severity HIGH || {
    log_warn "tfsec encontrou problemas de segurança de alta severidade."
    if [[ "$ENV" == "prod" ]]; then
      log_error "Deploy em produção bloqueado por issues de segurança do tfsec."
      exit 1
    fi
  }
else
  log_warn "tfsec não instalado. Recomendado: brew install tfsec"
fi

if command -v checkov >/dev/null 2>&1; then
  log_info "Executando checkov..."
  checkov -d "$ENV_DIR" --quiet --framework terraform || {
    log_warn "checkov encontrou problemas. Revise antes de prosseguir."
  }
else
  log_warn "checkov não instalado. Recomendado: pip install checkov"
fi

# ── Terraform init + validate + plan ─────────────────────────────────────────
cd "$ENV_DIR"

log_info "Inicializando Terraform (ambiente: $ENV)..."
terraform init -input=false -reconfigure

log_info "Formatando código..."
terraform fmt -recursive ../../

log_info "Validando configuração..."
terraform validate

log_info "Gerando plano de execução..."
# S4: Plan salvo no diretório .plans/ (dentro do repo, no .gitignore)
# Evita expor dados sensíveis do state em /tmp que é pasta compartilhada do sistema
PLANS_DIR="${ENV_DIR}/.plans"
mkdir -p "$PLANS_DIR"
chmod 700 "$PLANS_DIR"  # apenas o usuário atual pode acessar

PLAN_FILE="${PLANS_DIR}/tfplan-${ENV}-$(date +%Y%m%d-%H%M%S)"
terraform plan -input=false -out="$PLAN_FILE" -var-file="terraform.tfvars"


echo ""
log_warn "Revise o plano acima com cuidado antes de confirmar."
read -rp "Aplicar o plano? (yes/no): " APPLY_CONFIRM

if [[ "$APPLY_CONFIRM" != "yes" ]]; then
  log_info "Deploy cancelado pelo usuário."
  rm -f "$PLAN_FILE"
  exit 0
fi

# ── Apply ─────────────────────────────────────────────────────────────────────
log_info "Aplicando plano..."
terraform apply -input=false "$PLAN_FILE"

rm -f "$PLAN_FILE"
log_success "Deploy em $ENV concluído com sucesso!"
