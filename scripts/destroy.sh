#!/usr/bin/env bash
# scripts/destroy.sh
# Destrói infraestrutura com múltiplas confirmações (bloqueado em prod por padrão)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
  echo "Uso: $0 <ambiente> [--force-prod]"
  echo "  --force-prod  Necessário para destruir produção (use com extremo cuidado)"
  exit 1
}

[[ $# -lt 1 ]] && usage
ENV="$1"
FORCE_PROD="${2:-}"

case "$ENV" in
  dev|staging|prod) ;;
  *) log_error "Ambiente inválido: $ENV"; usage ;;
esac

# ❌ BLOQUEIO DUPLO em produção
if [[ "$ENV" == "prod" ]]; then
  if [[ "$FORCE_PROD" != "--force-prod" ]]; then
    log_error "BLOQUEADO: Para destruir produção, use: $0 prod --force-prod"
    log_error "Tenha ABSOLUTA certeza do que está fazendo."
    exit 1
  fi

  log_warn "🚨 DESTRUIÇÃO DE PRODUÇÃO SOLICITADA 🚨"
  log_warn "Isso removerá TODOS os recursos de produção permanentemente."
  log_warn "Backups do RDS serão excluídos se delete_automated_backups = true."

  read -rp "Digite o nome do projeto para confirmar: " PROJ_CONFIRM
  read -rp "Digite 'DESTRUIR PRODUÇÃO' para prosseguir: " FINAL_CONFIRM

  [[ "$FINAL_CONFIRM" != "DESTRUIR PRODUÇÃO" ]] && {
    log_error "Confirmação inválida. Operação cancelada."
    exit 1
  }
fi

ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/environments/$ENV"
[[ ! -d "$ENV_DIR" ]] && { log_error "Diretório não encontrado: $ENV_DIR"; exit 1; }

cd "$ENV_DIR"

log_info "Inicializando Terraform..."
terraform init -input=false -reconfigure

log_warn "Gerando plano de destruição para $ENV..."
terraform plan -destroy -var-file="terraform.tfvars"

echo ""
log_warn "Todos os recursos listados acima serão PERMANENTEMENTE DESTRUÍDOS."
read -rp "Confirma a destruição de $ENV? (yes/no): " DESTROY_CONFIRM

[[ "$DESTROY_CONFIRM" != "yes" ]] && { log_info "Operação cancelada."; exit 0; }

log_info "Destruindo infraestrutura de $ENV..."
terraform destroy -auto-approve -var-file="terraform.tfvars"

log_success "Infraestrutura de $ENV destruída."
