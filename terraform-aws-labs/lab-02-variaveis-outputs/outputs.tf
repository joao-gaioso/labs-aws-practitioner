# outputs.tf

output "account_id" {
  description = "ID da conta AWS utilizada"
  value       = data.aws_caller_identity.atual.account_id
}

output "ambiente" {
  description = "Ambiente onde os recursos foram criados"
  value       = var.environment
}

output "nomes_dos_buckets" {
  description = "Mapa com o nome de cada bucket criado"
  # Transforma o mapa de recursos em um mapa simples nome_funcao → nome_bucket
  value = {
    for funcao, bucket in aws_s3_bucket.buckets :
    funcao => bucket.bucket
  }
}

output "arns_dos_buckets" {
  description = "Mapa com o ARN de cada bucket criado"
  value = {
    for funcao, bucket in aws_s3_bucket.buckets :
    funcao => bucket.arn
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# EXPERIMENTO 2 — novo output de total de buckets
# Descomente após ler o Experimento 2 no README.
# length() retorna o número de itens em uma lista ou mapa.
# ─────────────────────────────────────────────────────────────────────────────
# output "total_de_buckets" {
#   description = "Quantos buckets foram criados"
#   value       = length(aws_s3_bucket.buckets)
# }

# ─────────────────────────────────────────────────────────────────────────────
# EXPERIMENTO 3 — output usando local calculado
# Descomente após descomentar os locals do Experimento 3.
# ─────────────────────────────────────────────────────────────────────────────
# output "prefixo_maiusculo" {
#   description = "Prefixo dos recursos em maiúsculas"
#   value       = local.prefixo_upper
# }

output "label_ambiente" {
  description = "Label legível do ambiente"
  value       = local.ambiente_label
}