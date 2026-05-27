# main.tf
# Aqui ficam os recursos que o Terraform vai criar na AWS.
#
# Estrutura de um recurso:
#   resource "<TIPO>" "<NOME_LOCAL>" { ... }
#
# O TIPO vem do provider (ex: aws_s3_bucket).
# O NOME_LOCAL é só um apelido dentro do Terraform (não aparece na AWS).

# ─── Bucket S3 ────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "meu_primeiro_bucket" {
  # O nome do bucket precisa ser único globalmente na AWS.
  # Usamos um sufixo aleatório para evitar conflito de nomes.
  bucket = "lab-terraform-${random_id.sufixo.hex}"

  tags = {
    Name = "lab-terraform-primeiro-bucket"
  }
}

# ─── Bloquear todo acesso público ─────────────────────────────────────────────
# Boa prática de segurança: buckets S3 devem ser privados por padrão.
# Este recurso garante que nenhuma configuração acidental torne o bucket público.
resource "aws_s3_bucket_public_access_block" "meu_primeiro_bucket" {
  bucket = aws_s3_bucket.meu_primeiro_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─── ID aleatório para o nome do bucket ───────────────────────────────────────
# O provider "random" gera valores aleatórios — útil para nomes únicos.
resource "random_id" "sufixo" {
  byte_length = 4
}
