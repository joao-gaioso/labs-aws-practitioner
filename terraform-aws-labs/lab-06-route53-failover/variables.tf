variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "nome_projeto" {
  description = "Nome do projeto — usado para compor nomes dos recursos"
  type        = string
  default     = "lab-failover"
}

variable "instance_type" {
  description = "Tipo da instância EC2 (t2.micro é elegível ao Free Tier)"
  type        = string
  default     = "t3.micro"
}

variable "hosted_zone_name" {
  description = <<-EOT
    Nome da Hosted Zone pública.
    IMPORTANTE: para health checks funcionarem, os registros precisam ser
    públicos. Use um domínio que você controle, ou mantenha o valor fictício
    abaixo — nesse caso os health checks vão falhar (Not Found), o que é
    suficiente para observar o comportamento de failover no console.
  EOT
  type        = string
  default     = "lojafacil-lab.com"
}

variable "health_check_path" {
  description = "Caminho HTTP que o Route 53 vai monitorar nas EC2"
  type        = string
  default     = "/health"
}

variable "health_check_intervalo" {
  description = "Intervalo em segundos entre cada verificação de saúde (mínimo: 10)"
  type        = number
  default     = 30
}

variable "health_check_threshold_saudavel" {
  description = "Número de checks consecutivos OK para considerar saudável"
  type        = number
  default     = 2
}

variable "health_check_threshold_falha" {
  description = "Número de checks consecutivos com falha para considerar não saudável"
  type        = number
  default     = 3
}
