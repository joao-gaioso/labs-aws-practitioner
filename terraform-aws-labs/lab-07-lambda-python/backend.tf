terraform {
  backend "s3" {
    bucket = "backend-labs-aws"
    key    = "lab-07-lambda-python/terraform.tfstate"
    region = "us-east-1"
  }
}
