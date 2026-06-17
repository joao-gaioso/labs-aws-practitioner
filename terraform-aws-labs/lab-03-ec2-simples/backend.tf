terraform {
  backend "s3" {
    bucket  = "SEU-BUCKET-AQUI"
    key     = "lab-03-ec2-simples/terraform.tfstate"
    region  = "us-east-1"
  }
}
