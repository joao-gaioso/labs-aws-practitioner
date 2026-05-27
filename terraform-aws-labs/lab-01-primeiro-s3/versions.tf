# versions.tf
# Boa prática: sempre fixe as versões do Terraform e dos providers.
# Isso garante que o lab funciona igual em qualquer máquina.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
