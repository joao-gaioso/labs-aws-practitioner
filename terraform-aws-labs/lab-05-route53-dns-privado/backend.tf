# ============================================================
# ATENÇÃO: preencha o campo bucket antes de rodar o init!
#
#  1. Abra este arquivo
#  2. Substitua "SEU-BUCKET-AQUI" pelo nome real do seu bucket S3
#  3. Salve e rode: terraform init
#
#  Exemplo:
#    bucket = "meu-bucket-terraform-estados"
# ============================================================

terraform {
  backend "s3" {
    bucket  = "SEU-BUCKET-AQUI"
    key     = "lab-05-route53-dns-privado/terraform.tfstate"
    region  = "us-east-1"
  }
}
