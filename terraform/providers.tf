provider "aws" {
  region = var.region

  assume_role {
    role_arn     = var.assume_role_arn
    session_name = "TerraformSession"
  }

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Owner       = "DevOps-Lab"
    }
  }
}
