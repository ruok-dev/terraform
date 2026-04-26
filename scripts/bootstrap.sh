#!/usr/bin/env bash
# scripts/bootstrap.sh
# Cria os recursos necessários ANTES do terraform init:
#   - S3 bucket para armazenar o Terraform state
#   - DynamoDB table para locking do state
#
# Execute UMA VEZ por ambiente antes de qualquer terraform init.
# Uso: bash scripts/bootstrap.sh <ambiente> <account_id>
# Ex:  bash scripts/bootstrap.sh dev 123456789012

set -euo pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}    $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}      $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   $*" >&2; }

# ── Argumentos ────────────────────────────────────────────────────────────────
usage() {
  echo ""
  echo "  Uso: $0 <ambiente> <account_id> [região]"
  echo ""
  echo "  Argumentos:"
  echo "    ambiente    dev | staging | prod"
  echo "    account_id  ID da conta AWS (12 dígitos)"
  echo "    região      Região AWS (padrão: us-east-1)"
  echo ""
  echo "  Exemplos:"
  echo "    $0 dev 123456789012"
  echo "    $0 prod 123456789012 us-west-2"
  echo ""
  exit 1
}

[[ $# -lt 2 ]] && usage

ENV="$1"
ACCOUNT_ID="$2"
REGION="${3:-us-east-1}"

case "$ENV" in
  dev|staging|prod) ;;
  *) log_error "Ambiente inválido: $ENV"; usage ;;
esac

# Valida que o account_id tem 12 dígitos
if ! [[ "$ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
  log_error "Account ID inválido: '$ACCOUNT_ID'. Deve ter 12 dígitos."
  exit 1
fi

# Verifica pré-requisitos
command -v aws >/dev/null 2>&1 || { log_error "aws CLI não encontrado"; exit 1; }
command -v jq  >/dev/null 2>&1 || log_warn "jq não encontrado — saída pode ser menos legível"

# ── Configurações ─────────────────────────────────────────────────────────────
PROFILE="terraform-${ENV}"
BUCKET_NAME="terraform-state-${ENV}-${ACCOUNT_ID}"
TABLE_NAME="terraform-state-lock"
PROJECT_TAG="terraform-aws-infra"

echo ""
log_info "=== BOOTSTRAP DE INFRAESTRUTURA TERRAFORM ==="
log_info "Ambiente   : ${ENV}"
log_info "Account ID : ${ACCOUNT_ID}"
log_info "Região     : ${REGION}"
log_info "Bucket     : ${BUCKET_NAME}"
log_info "DynamoDB   : ${TABLE_NAME}"
log_info "Perfil AWS : ${PROFILE}"
echo ""

# Confirma antes de criar em prod
if [[ "$ENV" == "prod" ]]; then
  log_warn "⚠️  Você está criando recursos em PRODUÇÃO!"
  read -rp "Digite 'PRODUÇÃO' para confirmar: " CONFIRM
  [[ "$CONFIRM" != "PRODUÇÃO" ]] && { log_error "Cancelado."; exit 1; }
fi

# ── Verificar se o bucket já existe ──────────────────────────────────────────
log_info "Verificando se o bucket S3 já existe..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$PROFILE" 2>/dev/null; then
  log_warn "Bucket '${BUCKET_NAME}' já existe. Pulando criação."
else
  # ── Criar S3 Bucket ────────────────────────────────────────────────────────
  log_info "Criando bucket S3: ${BUCKET_NAME}..."

  if [[ "$REGION" == "us-east-1" ]]; then
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$REGION" \
      --profile "$PROFILE"
  else
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION" \
      --profile "$PROFILE"
  fi

  log_success "Bucket criado: ${BUCKET_NAME}"

  # Bloqueia acesso público
  log_info "Bloqueando acesso público ao bucket..."
  aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --profile "$PROFILE"
  log_success "Acesso público bloqueado."

  # Habilita versionamento
  log_info "Habilitando versionamento..."
  aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --profile "$PROFILE"
  log_success "Versionamento ativado."

  # Habilita criptografia KMS
  log_info "Habilitando criptografia SSE-KMS..."
  aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"},"BucketKeyEnabled":true}]}' \
    --profile "$PROFILE"
  log_success "Criptografia KMS ativada."

  # Tags
  aws s3api put-bucket-tagging \
    --bucket "$BUCKET_NAME" \
    --tagging "TagSet=[{Key=Purpose,Value=terraform-state},{Key=Environment,Value=${ENV}},{Key=Project,Value=${PROJECT_TAG}},{Key=ManagedBy,Value=bootstrap-script}]" \
    --profile "$PROFILE"

  # Política de lifecycle para versões antigas (retém por 90 dias)
  log_info "Configurando lifecycle policy..."
  aws s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET_NAME" \
    --lifecycle-configuration '{
      "Rules": [{
        "ID": "expire-old-state-versions",
        "Status": "Enabled",
        "NoncurrentVersionExpiration": {"NoncurrentDays": 90},
        "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": 7}
      }]
    }' \
    --profile "$PROFILE"
  log_success "Lifecycle policy configurada."
fi

# ── Verificar se a tabela DynamoDB já existe ──────────────────────────────────
log_info "Verificando DynamoDB table: ${TABLE_NAME}..."
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" --profile "$PROFILE" 2>/dev/null | grep -q ACTIVE; then
  log_warn "Tabela '${TABLE_NAME}' já existe. Pulando criação."
else
  # ── Criar DynamoDB Table ───────────────────────────────────────────────────
  log_info "Criando tabela DynamoDB: ${TABLE_NAME}..."
  aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" \
    --profile "$PROFILE" \
    --tags \
      Key=Purpose,Value=terraform-state-lock \
      Key=Environment,Value="$ENV" \
      Key=Project,Value="$PROJECT_TAG" \
      Key=ManagedBy,Value=bootstrap-script

  # Aguarda a tabela ficar ativa
  log_info "Aguardando tabela ficar ativa..."
  aws dynamodb wait table-exists \
    --table-name "$TABLE_NAME" \
    --region "$REGION" \
    --profile "$PROFILE"

  # Habilita PITR (Point-in-Time Recovery)
  aws dynamodb update-continuous-backups \
    --table-name "$TABLE_NAME" \
    --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
    --region "$REGION" \
    --profile "$PROFILE"

  log_success "Tabela DynamoDB criada com PITR ativo."
fi

# ── Resultado final ───────────────────────────────────────────────────────────
echo ""
log_success "=== BOOTSTRAP CONCLUÍDO ==="
echo ""
log_info "Atualize o arquivo environments/${ENV}/backend.tf com os valores abaixo:"
echo ""
echo "  terraform {"
echo "    backend \"s3\" {"
echo "      bucket         = \"${BUCKET_NAME}\""
echo "      key            = \"${ENV}/terraform.tfstate\""
echo "      region         = \"${REGION}\""
echo "      encrypt        = true"
echo "      dynamodb_table = \"${TABLE_NAME}\""
echo "      profile        = \"${PROFILE}\""
echo "    }"
echo "  }"
echo ""
log_warn "⚠️  Não commite o backend.tf com dados reais no Git!"
log_warn "    Use os placeholders como exemplos e configure via CI/CD secrets."
