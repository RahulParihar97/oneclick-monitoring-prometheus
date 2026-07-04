terraform {
  # Enforce Terraform version
  required_version = ">= 1.5.0"

  # Define required providers
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}
