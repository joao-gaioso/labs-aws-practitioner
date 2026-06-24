variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "nome_projeto" {
  description = "Nome do projeto — usado para compor nomes dos recursos"
  type        = string
  default     = "lab-lambda"
}

variable "runtime" {
  description = "Runtime Python da Lambda (ex: python3.13, python3.12)"
  type        = string
  default     = "python3.13"
}

variable "timeout" {
  description = "Timeout máximo de execução em segundos (máximo permitido: 900)"
  type        = number
  default     = 10
}

variable "memory_size" {
  description = "Memória alocada para a Lambda em MB (mínimo: 128, máximo: 10240)"
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "Dias de retenção dos logs no CloudWatch Logs (0 = nunca expirar)"
  type        = number
  default     = 7
}

# ─────────────────────────────────────────────────────────────────────────────
# 🧪 VARIÁVEL DOS EXPERIMENTOS
# Altere aqui para ver o nome mudar na resposta da Lambda sem mexer no código.
# ─────────────────────────────────────────────────────────────────────────────
variable "nome_padrao" {
  description = "Nome padrão da saudação quando o evento não traz um 'nome'"
  type        = string
  default     = "Mundo"
}