#!/usr/bin/env bash
# scripts/validate.sh
# Validação completa: fmt, validate, tfsec, checkov

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

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0

# ── 1. Formato ────────────────────────────────────────────────────────────────
log_info "Verificando formatação Terraform..."
if terraform fmt -check -recursive "$ROOT_DIR"; then
  log_success "Formatação OK"
else
  log_warn "Código fora do padrão. Execute: terraform fmt -recursive ."
  ERRORS=$((ERRORS + 1))
fi

# ── 2. Validate por ambiente ──────────────────────────────────────────────────
for env_dir in "$ROOT_DIR"/environments/*/; do
  env=$(basename "$env_dir")
  log_info "Validando ambiente: $env..."
  cd "$env_dir"

  if terraform init -backend=false -input=false -no-color > /dev/null 2>&1; then
    if terraform validate -no-color; then
      log_success "Validação OK: $env"
    else
      log_error "Validação falhou: $env"
      ERRORS=$((ERRORS + 1))
    fi
  else
    log_warn "Não foi possível inicializar $env (ignorado no validate)"
  fi

  cd "$ROOT_DIR"
done

# ── 3. Verifica credenciais hardcoded ────────────────────────────────────────
log_info "Verificando credenciais hardcoded..."
CRED_PATTERN='(aws_access_key_id\s*=\s*"AKIA|password\s*=\s*"[A-Za-z0-9!@#\$%]{8,}")'
if grep -rn --include="*.tf" -E "$CRED_PATTERN" "$ROOT_DIR" 2>/dev/null | grep -v "var\." | grep -v "#"; then
  log_error "Credenciais hardcoded encontradas!"
  ERRORS=$((ERRORS + 1))
else
  log_success "Nenhuma credencial hardcoded."
fi

# ── 4. tfsec ─────────────────────────────────────────────────────────────────
if command -v tfsec >/dev/null 2>&1; then
  log_info "Executando tfsec..."
  if tfsec "$ROOT_DIR" --minimum-severity MEDIUM --no-color; then
    log_success "tfsec: sem problemas"
  else
    log_warn "tfsec encontrou issues. Verifique antes do deploy."
    ERRORS=$((ERRORS + 1))
  fi
else
  log_warn "tfsec não instalado (brew install tfsec | apt install tfsec)"
fi

# ── 5. checkov ───────────────────────────────────────────────────────────────
if command -v checkov >/dev/null 2>&1; then
  log_info "Executando checkov..."
  if checkov -d "$ROOT_DIR" --quiet --framework terraform --compact; then
    log_success "checkov: sem problemas"
  else
    log_warn "checkov encontrou issues. Revise o relatório acima."
    ERRORS=$((ERRORS + 1))
  fi
else
  log_warn "checkov não instalado (pip install checkov)"
fi

# ── Resultado final ───────────────────────────────────────────────────────────
echo ""
if [[ $ERRORS -eq 0 ]]; then
  log_success "✅ Todas as validações passaram!"
  exit 0
else
  log_error "❌ $ERRORS validação(ões) com problema. Corrija antes do deploy."
  exit 1
fi
