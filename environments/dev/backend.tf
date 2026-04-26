# environments/dev/backend.tf
# Backend remoto seguro: state no S3 + lock via DynamoDB

terraform {
  backend "s3" {
    bucket         = "SUBSTITUIR-terraform-state-ACCOUNT_ID"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "SUBSTITUIR-terraform-state-lock"
    profile        = "terraform-dev" # perfil AWS CLI — sem credenciais hardcoded
  }
}
