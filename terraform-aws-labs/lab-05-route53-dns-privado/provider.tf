provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Lab       = "lab-05-route53-dns-privado"
    }
  }
}
