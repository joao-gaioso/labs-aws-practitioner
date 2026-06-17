variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
  default     = "t2.micro" # elegível ao Free Tier
}

variable "nome_projeto" {
  description = "Nome do projeto — usado para nomear os recursos"
  type        = string
  default     = "lab-ec2"
}
