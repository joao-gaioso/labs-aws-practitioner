provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Lab       = "lab-03-ec2-simples"
    }
  }
}
