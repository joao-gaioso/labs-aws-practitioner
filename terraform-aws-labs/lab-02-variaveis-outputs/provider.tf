provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Lab         = "lab-02-variaveis-outputs"
      Environment = var.environment
    }
  }
}
