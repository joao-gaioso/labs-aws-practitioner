# main.tf

# ─── Data source: AMI mais recente do Amazon Linux 2023 ───────────────────────
# Em vez de hardcodar o ID da AMI (que muda por região e versão),
# usamos um data source para buscar sempre a versão mais recente.
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

# ─── Data source: VPC padrão da conta ─────────────────────────────────────────
# Toda conta AWS tem uma VPC padrão em cada região.
# Usamos ela para simplificar o lab — em produção você criaria sua própria VPC.
data "aws_vpc" "padrao" {
  default = true
}

# ─── Par de chaves SSH ────────────────────────────────────────────────────────
# Geramos o par de chaves dentro do Terraform para facilitar o lab.
# Boa prática em produção: gere o par de chaves fora do Terraform
# e importe apenas a chave pública.
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

# Salva a chave privada localmente para uso com SSH
resource "local_sensitive_file" "chave_privada" {
  content         = tls_private_key.chave_lab.private_key_pem
  filename        = "${path.module}/${var.nome_projeto}-key.pem"
  file_permission = "0400" # somente leitura pelo dono — obrigatório para SSH
}

# ─── Security Group ───────────────────────────────────────────────────────────
# O Security Group é o firewall da EC2.
# Boa prática: libere apenas as portas necessárias e restrinja o SSH
# ao seu IP em vez de 0.0.0.0/0.
resource "aws_security_group" "ec2_sg" {
  name        = "${var.nome_projeto}-sg"
  description = "Security Group do lab EC2 - permite SSH"
  vpc_id      = data.aws_vpc.padrao.id

  # Regra de entrada: SSH (porta 22)
  # ⚠️  0.0.0.0/0 libera para qualquer IP — aceitável em lab, não em produção.
  # Em produção substitua por: cidr_blocks = ["SEU_IP/32"]
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra de saída: libera todo tráfego de saída (padrão AWS)
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
resource "aws_instance" "lab" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.chave_lab.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # Boa prática: desabilitar acesso a metadados via IMDSv1 (menos seguro).
  # Força o uso de IMDSv2 com token de sessão.
  metadata_options {
    http_tokens = "required"
  }

  # user_data executa comandos na primeira inicialização da instância
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    echo "Lab EC2 provisionado pelo Terraform em $(date)" > /home/ec2-user/lab.txt
  EOF

  tags = {
    Name = "${var.nome_projeto}-instance"
  }
}
