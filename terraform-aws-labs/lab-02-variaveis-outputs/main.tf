# main.tf
# Neste lab criamos múltiplos buckets S3 usando um loop (for_each).
# O for_each evita repetir o mesmo bloco de recurso várias vezes.

# ─── Data source: Account ID atual ────────────────────────────────────────────
# Data sources buscam informações existentes na AWS sem criar nada.
# Aqui pegamos o Account ID para usar no nome do bucket (garante unicidade).
data "aws_caller_identity" "atual" {}

# ─── Buckets S3 ───────────────────────────────────────────────────────────────
# for_each itera sobre a lista de buckets e cria um recurso para cada item.
# toset() converte a lista em conjunto (necessário para o for_each).
resource "aws_s3_bucket" "buckets" {
  for_each = toset(var.buckets)

  # each.key é o item atual da iteração (ex: "uploads", "backups", "logs")
  bucket = "${local.prefixo}-${each.key}-${data.aws_caller_identity.atual.account_id}"

  tags = merge(local.tags_comuns, {
    Name   = "${local.prefixo}-${each.key}"
    Funcao = each.key
  })
}

# ─── Bloquear acesso público em todos os buckets ──────────────────────────────
resource "aws_s3_bucket_public_access_block" "buckets" {
  for_each = aws_s3_bucket.buckets

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─────────────────────────────────────────────────────────────────────────────
# EXPERIMENTO 4 — Versionamento nos buckets
# Descomente o bloco abaixo após ler o Experimento 4 no README.
# O versionamento guarda todas as versões de cada arquivo — protege contra
# deleções acidentais e permite recuperar versões anteriores.
# ─────────────────────────────────────────────────────────────────────────────
# resource "aws_s3_bucket_versioning" "buckets" {
#   for_each = aws_s3_bucket.buckets

#   bucket = each.value.id

#   versioning_configuration {
#     status = var.versioning_enabled ? "Enabled" : "Suspended"
#   }
# }

# ─────────────────────────────────────────────────────────────────────────────
# EXPERIMENTO 5 — Bucket exclusivo para o ambiente de produção
# Descomente o bloco abaixo após ler o Experimento 5 no README.
# O count = 0 ou 1 é uma forma de criar um recurso condicionalmente.
# ─────────────────────────────────────────────────────────────────────────────
# resource "aws_s3_bucket" "auditoria" {
#   count = var.environment == "prod" ? 1 : 0

#   bucket = "${local.prefixo}-auditoria-${data.aws_caller_identity.atual.account_id}"

#   tags = merge(local.tags_comuns, {
#     Name   = "${local.prefixo}-auditoria"
#     Funcao = "auditoria"
#   })
# }

# resource "aws_s3_bucket_public_access_block" "auditoria" {
#   count = var.environment == "prod" ? 1 : 0

#   bucket = aws_s3_bucket.auditoria[0].id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }