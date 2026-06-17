provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Lab       = "lab-06-route53-failover"
    }
  }
}
