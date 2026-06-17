# main.tf
#
# Arquitetura deste lab:
#
#   EC2 (nginx)  ←──────────────────────────────────┐
#       ↑                                            │
#   Route 53 Record A  →  app.lojafacil.internal    │
#       ↑                                            │
#   Hosted Zone Privada → lojafacil.internal         │
#       ↑                                            │
#   VPC padrão da conta ─────────────────────────────┘
#
# O nome "app.lojafacil.internal" só resolve dentro da VPC.
# Para testar, a aluna conecta na EC2 via SSH e roda: curl http://app.lojafacil.internal

# ─── Data sources ─────────────────────────────────────────────────────────────

# VPC padrão da conta — usada para associar a Hosted Zone privada
data "aws_vpc" "padrao" {
  default = true
}

# AMI mais recente do Amazon Linux 2023
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─── Par de chaves SSH ────────────────────────────────────────────────────────

resource "tls_private_key" "chave_lab" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "chave_lab" {
  key_name   = "${var.nome_projeto}-key"
  public_key = tls_private_key.chave_lab.public_key_openssh

  tags = {
    Name = "${var.nome_projeto}-key"
  }
}

resource "local_sensitive_file" "chave_privada" {
  content         = tls_private_key.chave_lab.private_key_pem
  filename        = "${path.module}/${var.nome_projeto}-key.pem"
  file_permission = "0400"
}

# ─── Security Group ───────────────────────────────────────────────────────────

resource "aws_security_group" "ec2" {
  name        = "${var.nome_projeto}-sg"
  description = "Permite SSH e HTTP para o lab Route 53"
  vpc_id      = data.aws_vpc.padrao.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Todo trafego de saida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.nome_projeto}-sg"
  }
}

# ─── Instância EC2 ────────────────────────────────────────────────────────────

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.chave_lab.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]

  metadata_options {
    http_tokens = "required"
  }

  # user_data instala o nginx e cria uma página de boas-vindas personalizada
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx
    yum install -y nginx bind-utils
    systemctl enable nginx
    systemctl start nginx
    echo "<h1>Bem-vinda ao lab Route 53!</h1><p>Servidor: $(hostname)</p><p>IP privado: $(hostname -I)</p>" > /usr/share/nginx/html/index.html
  EOF

  tags = {
    Name = "${var.nome_projeto}-app"
  }
}

# ─── Hosted Zone Privada ──────────────────────────────────────────────────────
#
# Uma Hosted Zone é como uma "pasta" no Route 53 que agrupa todos os
# registros DNS de um domínio.
#
# Privada = só resolve dentro da VPC associada.
# Pública = resolve na internet (precisa de domínio registrado).

resource "aws_route53_zone" "privada" {
  name    = var.dominio_privado
  comment = "Hosted Zone privada do lab Route 53 — ${var.nome_projeto}"

  # Associação com a VPC — o que torna a zona privada
  vpc {
    vpc_id = data.aws_vpc.padrao.id
  }

  tags = {
    Name = var.dominio_privado
  }
}

# ─── Registro DNS: app ────────────────────────────────────────────────────────
#
# Um Record A mapeia um nome (app.lojafacil.internal) para um IP (da EC2).
# TTL = Time To Live: por quantos segundos o DNS fica em cache.
# Com TTL baixo (ex: 60s), mudanças propagam mais rápido.
# Com TTL alto (ex: 3600s), mudanças demoram mais mas reduzem consultas ao DNS.

resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.privada.zone_id
  name    = "app.${var.dominio_privado}"
  type    = "A"
  ttl     = var.dns_ttl
  records = [aws_instance.app.private_ip]
}

# ─────────────────────────────────────────────────────────────────────────────
# 🧪 EXPERIMENTO 3 — Registro CNAME
# Descomente o bloco abaixo após concluir o Experimento 3 no README.
# Um CNAME cria um "apelido" que aponta para outro nome DNS (não para um IP).
# ─────────────────────────────────────────────────────────────────────────────
# resource "aws_route53_record" "www" {
#   zone_id = aws_route53_zone.privada.zone_id
#   name    = "www.${var.dominio_privado}"
#   type    = "CNAME"
#   ttl     = var.dns_ttl
#   records = [aws_route53_record.app.fqdn]
# }

# ─────────────────────────────────────────────────────────────────────────────
# 🧪 EXPERIMENTO 4 — Segunda EC2 e registro DNS separado
# Descomente o bloco abaixo após concluir o Experimento 4 no README.
# ─────────────────────────────────────────────────────────────────────────────
# resource "aws_instance" "api" {
#   ami                    = data.aws_ami.amazon_linux.id
#   instance_type          = var.instance_type
#   key_name               = aws_key_pair.chave_lab.key_name
#   vpc_security_group_ids = [aws_security_group.ec2.id]
#
#   metadata_options {
#     http_tokens = "required"
#   }
#
#   user_data = <<-EOF
#     #!/bin/bash
#     yum update -y
#     yum install -y nginx
#     systemctl enable nginx
#     systemctl start nginx
#     echo "<h1>API Server</h1><p>Servidor: $(hostname)</p><p>IP: $(hostname -I)</p>" > /usr/share/nginx/html/index.html
#   EOF
#
#   tags = {
#     Name = "${var.nome_projeto}-api"
#   }
# }
#
# resource "aws_route53_record" "api" {
#   zone_id = aws_route53_zone.privada.zone_id
#   name    = "api.${var.dominio_privado}"
#   type    = "A"
#   ttl     = var.dns_ttl
#   records = [aws_instance.api.private_ip]
# }

# ─────────────────────────────────────────────────────────────────────────────
# 🧪 EXPERIMENTO 5 — Registro TXT (metadados no DNS)
# Descomente o bloco abaixo após concluir o Experimento 5 no README.
# ─────────────────────────────────────────────────────────────────────────────
# resource "aws_route53_record" "txt_info" {
#   zone_id = aws_route53_zone.privada.zone_id
#   name    = var.dominio_privado
#   type    = "TXT"
#   ttl     = 60
#   records = ["ambiente=lab", "time=catalogo", "versao=1.0"]
# }
