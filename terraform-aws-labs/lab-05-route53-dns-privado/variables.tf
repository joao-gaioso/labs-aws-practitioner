variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "nome_projeto" {
  description = "Nome do projeto — usado para compor nomes dos recursos"
  type        = string
  default     = "lojafacil"
}

variable "dominio_privado" {
  description = "Domínio da Hosted Zone privada (só resolve dentro da VPC)"
  type        = string
  default     = "lojafacil.internal"
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
  default     = "t3.micro"
}

# ─────────────────────────────────────────────────────────────────────────────
# 🧪 VARIÁVEL DOS EXPERIMENTOS
# Controla o TTL dos registros DNS. Altere aqui para ver o efeito nos testes.
# ─────────────────────────────────────────────────────────────────────────────
variable "dns_ttl" {
  description = "TTL dos registros DNS em segundos (quanto tempo o DNS fica em cache)"
  type        = number
  default     = 300
}
