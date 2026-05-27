# outputs.tf
# Outputs exibem informações sobre os recursos criados após o apply.
# São úteis para saber o nome/ARN/URL do que foi criado sem precisar
# entrar no console da AWS.

output "bucket_name" {
  description = "Nome do bucket S3 criado"
  value       = aws_s3_bucket.meu_primeiro_bucket.bucket
}

output "bucket_arn" {
  description = "ARN do bucket S3 (identificador único global)"
  value       = aws_s3_bucket.meu_primeiro_bucket.arn
}

output "bucket_region" {
  description = "Região onde o bucket foi criado"
  value       = aws_s3_bucket.meu_primeiro_bucket.region
}
