terraform {
  backend "s3" {
    bucket  = "SEU-BUCKET-AQUI"
    key     = "lab-06-route53-failover/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
