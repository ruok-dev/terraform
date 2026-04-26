# environments/staging/backend.tf
terraform {
  backend "s3" {
    bucket         = "SUBSTITUIR-terraform-state-ACCOUNT_ID"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "SUBSTITUIR-terraform-state-lock"
    profile        = "terraform-staging"
  }
}
