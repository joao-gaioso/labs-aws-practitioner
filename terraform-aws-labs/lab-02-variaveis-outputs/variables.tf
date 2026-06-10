# variables.tf
# Variáveis tornam o código reutilizável e evitam valores hardcoded.
#
# Estrutura de uma variável:
#   variable "<NOME>" {
#     description = "para que serve"
#     type        = string | number | bool | list | map | object
#     default     = valor padrão (opcional — se omitido, o Terraform pede na hora do apply)
#   }

variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente da infraestrutura (dev, staging, prod)"
  type        = string
  default     = "dev"

  # validation garante que só valores válidos sejam aceitos
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "O ambiente deve ser dev, staging ou prod."
  }
}

variable "projeto" {
  description = "Nome do projeto — usado para compor os nomes dos recursos"
  type        = string
  default     = "lab-ana"
}

variable "buckets" {
  description = "Lista de buckets S3 a serem criados"
  type        = list(string)
  default     = ["uploads", "backups", "logs"]
}

# ─────────────────────────────────────────────────────────────────────────────
# EXPERIMENTO 4 — variável de controle do versionamento
# Descomente após ler o Experimento 4 no README.
# ─────────────────────────────────────────────────────────────────────────────
# variable "versioning_enabled" {
#   description = "Ativa ou desativa o versionamento nos buckets S3"
#   type        = bool
#   default     = false
# }