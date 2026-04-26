# environments/prod/backend.tf
# Backend remoto seguro: state no S3 + lock via DynamoDB
# ⚠️  Substitua ACCOUNT_ID pelo ID real da sua conta AWS
# ⚠️  Este arquivo deve ter apenas placeholders — NUNCA valores reais commitados

terraform {
  backend "s3" {
    bucket         = "SUBSTITUIR-terraform-state-ACCOUNT_ID"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "SUBSTITUIR-terraform-state-lock"
    profile        = "terraform-prod" # perfil AWS CLI — sem credenciais hardcoded
  }
}
