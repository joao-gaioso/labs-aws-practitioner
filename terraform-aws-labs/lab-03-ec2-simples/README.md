# Lab 03 — EC2 Simples

## 🎯 Objetivo

Criar uma instância EC2 com Terraform aplicando boas práticas: AMI dinâmica via data source, Security Group com regras explícitas, par de chaves gerado automaticamente e IMDSv2 habilitado.

## 📁 Estrutura dos arquivos

```
lab-03-ec2-simples/
├── versions.tf    → versões fixadas (inclui providers tls e local)
├── provider.tf    → provider AWS
├── variables.tf   → variáveis de entrada
├── main.tf        → EC2, Security Group, par de chaves, data sources
└── outputs.tf     → IP público, comando SSH pronto
```

## 🧱 O que será criado

- 1 par de chaves SSH (gerado pelo Terraform, salvo localmente como `.pem`)
- 1 Security Group com SSH liberado
- 1 instância EC2 `t2.micro` com Amazon Linux 2023 (Free Tier)

## 🚀 Executando o lab

```bash
terraform init
terraform plan
terraform apply
```

Após o apply, o output `comando_ssh` já mostra o comando pronto para conectar:

```bash
terraform output comando_ssh
# ssh -i lab-ec2-key.pem ec2-user@<IP_PUBLICO>
```

## 🔍 Verificando a instância

```bash
# Ver o IP público
terraform output ip_publico

# Ver qual AMI foi usada
terraform output ami_utilizada

# Conectar via SSH
ssh -i lab-ec2-key.pem ec2-user@$(terraform output -raw ip_publico)
```

## 💡 Conceitos deste lab

**`data "aws_ami"`** — busca a AMI mais recente do Amazon Linux 2023 sem hardcodar o ID. O ID da AMI muda por região e versão — data source resolve isso automaticamente.

**`data "aws_vpc"`** — busca a VPC padrão da conta. Data sources leem recursos existentes sem criar nada.

**Security Group** — firewall da EC2. Sempre declare `ingress` e `egress` explicitamente. Em produção, restrinja o SSH ao seu IP (`SEU_IP/32`) em vez de `0.0.0.0/0`.

**`tls_private_key`** — gera um par de chaves RSA dentro do Terraform. Prático para labs; em produção gere fora e importe só a pública.

**`local_sensitive_file`** — salva a chave privada localmente com permissão `0400`. O `sensitive` garante que o conteúdo não apareça nos logs do Terraform.

**`metadata_options { http_tokens = "required" }`** — força IMDSv2, que exige um token de sessão para acessar os metadados da instância. Protege contra ataques SSRF.

**`user_data`** — script executado na primeira inicialização da instância. Útil para instalar pacotes, configurar serviços, etc.

## ⚠️ Boas práticas de segurança aplicadas

- IMDSv2 obrigatório (`http_tokens = "required"`)
- Chave privada salva com permissão `0400`
- Security Group com regras explícitas de ingress e egress
- AMI buscada dinamicamente (sem ID hardcoded)

## 🧹 Destruindo os recursos

```bash
terraform destroy
```

> O arquivo `.pem` gerado localmente não é removido pelo `destroy`. Delete manualmente se necessário.
