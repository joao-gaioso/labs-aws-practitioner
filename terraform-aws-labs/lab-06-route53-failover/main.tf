# main.tf
#
# Arquitetura deste lab:
#
#   Route 53 Health Check ──► EC2 Primária (porta 80 /health)
#          │
#          │  se falhar 3x consecutivos
#          ▼
#   Route 53 Failover Record
#     PRIMARY  → EC2 Primária  (associado ao health check)
#     SECONDARY → EC2 Secundária (ativado quando PRIMARY está unhealthy)
#
# O cliente sempre resolve "app.lojafacil-lab.com".
# Quando a primária cai, o DNS automaticamente passa a responder com o IP
# da secundária — sem nenhuma intervenção manual.

# ─── Data sources ─────────────────────────────────────────────────────────────

data "aws_vpc" "padrao" {
  default = true
}

# Busca subnets da VPC padrão excluindo us-east-1e, que não suporta t3.micro
data "aws_subnets" "padrao" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.padrao.id]
  }

  filter {
    name   = "availabilityZone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
  }
}

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
# O health check do Route 53 vem dos IPs da AWS — precisamos liberar HTTP
# de qualquer origem para que os checks funcionem.

resource "aws_security_group" "ec2" {
  name        = "${var.nome_projeto}-sg"
  description = "Permite SSH e HTTP - necessario para health checks do Route 53"
  vpc_id      = data.aws_vpc.padrao.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP - usado pelo health check do Route 53"
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

# ─── EC2 Primária ─────────────────────────────────────────────────────────────
# Instalamos nginx e criamos dois endpoints:
#   GET /          → página principal
#   GET /health    → endpoint monitorado pelo Route 53 health check

resource "aws_instance" "primaria" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.chave_lab.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  # Coloca a primária na primeira subnet disponível
  subnet_id = data.aws_subnets.padrao.ids[0]

  metadata_options {
    http_tokens = "required"
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx
    systemctl enable nginx
    systemctl start nginx

    # Página principal
    echo "<h1>SERVIDOR PRIMÁRIO</h1><p>Host: $(hostname)</p><p>IP: $(hostname -I)</p><p>AZ: $(TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60') && curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>" \
      > /usr/share/nginx/html/index.html

    # Endpoint de health check — retorna 200 OK
    mkdir -p /usr/share/nginx/html
    echo "OK" > /usr/share/nginx/html/health
  EOF

  tags = {
    Name = "${var.nome_projeto}-primaria"
    Role = "primary"
  }
}

# ─── EC2 Secundária ───────────────────────────────────────────────────────────
# Fica em standby — só recebe tráfego quando a primária for considerada falha.

resource "aws_instance" "secundaria" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.chave_lab.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  # Coloca a secundária na segunda subnet (AZ diferente da primária)
  subnet_id = data.aws_subnets.padrao.ids[1]

  metadata_options {
    http_tokens = "required"
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx
    systemctl enable nginx
    systemctl start nginx

    # Página principal — identifica claramente que é o servidor de backup
    echo "<h1>⚠️ SERVIDOR SECUNDÁRIO (FAILOVER)</h1><p>Host: $(hostname)</p><p>IP: $(hostname -I)</p><p>AZ: $(TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60') && curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>" \
      > /usr/share/nginx/html/index.html

    # Endpoint de health check
    echo "OK" > /usr/share/nginx/html/health
  EOF

  tags = {
    Name = "${var.nome_projeto}-secundaria"
    Role = "secondary"
  }
}

# ─── Route 53 Health Check ────────────────────────────────────────────────────
# O health check monitora o endpoint HTTP da EC2 primária.
# O Route 53 envia requisições periódicas de múltiplas regiões da AWS.
# Se o número de falhas consecutivas atingir o threshold, o registro é
# marcado como "unhealthy" e o failover é ativado.

resource "aws_route53_health_check" "primaria" {
  ip_address        = aws_instance.primaria.public_ip
  port              = 80
  type              = "HTTP"
  resource_path     = var.health_check_path
  request_interval  = var.health_check_intervalo
  failure_threshold = var.health_check_threshold_falha

  tags = {
    Name = "${var.nome_projeto}-hc-primaria"
  }
}

# ─── Hosted Zone Pública ──────────────────────────────────────────────────────
# Health checks do Route 53 só funcionam com zonas PÚBLICAS.
# A zona pública não precisa de um domínio registrado para existir no Route 53,
# mas os registros só resolverão na internet se o domínio for registrado
# e os nameservers do Route 53 forem configurados no registrador.
# Para fins de lab, criamos a zona e observamos o comportamento no console.

resource "aws_route53_zone" "publica" {
  name    = var.hosted_zone_name
  comment = "Hosted Zone pública do lab failover — ${var.nome_projeto}"

  tags = {
    Name = var.hosted_zone_name
  }
}

# ─── Registro DNS PRIMARY ─────────────────────────────────────────────────────
# O registro PRIMARY é o destino preferencial.
# Está associado ao health check — se o check falhar, este registro
# é automaticamente removido das respostas DNS.

resource "aws_route53_record" "app_primary" {
  zone_id = aws_route53_zone.publica.zone_id
  name    = "app.${var.hosted_zone_name}"
  type    = "A"
  ttl     = 60 # TTL baixo para failover propagar rápido

  # Política de roteamento: FAILOVER
  failover_routing_policy {
    type = "PRIMARY"
  }

  # Identificador único do registro (obrigatório quando há múltiplos
  # registros com o mesmo nome e tipo)
  set_identifier = "primary"

  # Vincula ao health check — sem isso o failover não funciona
  health_check_id = aws_route53_health_check.primaria.id

  records = [aws_instance.primaria.public_ip]
}

# ─── Registro DNS SECONDARY ───────────────────────────────────────────────────
# O registro SECONDARY é o destino de fallback.
# Só é usado quando o PRIMARY está unhealthy.
# Não precisa de health check próprio — o Route 53 o usa automaticamente
# quando o PRIMARY falha.

resource "aws_route53_record" "app_secondary" {
  zone_id = aws_route53_zone.publica.zone_id
  name    = "app.${var.hosted_zone_name}"
  type    = "A"
  ttl     = 60

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "secondary"

  records = [aws_instance.secundaria.public_ip]
}
