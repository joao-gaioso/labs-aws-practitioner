terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # archive: empacota o código Python em .zip para o deploy da Lambda
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}
