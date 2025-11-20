# =============================================================================
# BACKEND CONFIGURATION - CI/CD STANDALONE
# =============================================================================

terraform {
  /*
  # Backend local - estado en terraform.tfstate
  # Para usar S3 backend, descomenta y configura:
  
  backend "s3" {
    bucket         = "cicd-iac-terraform-state-dev-dam2ffrv"
    key            =  "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
  */
}