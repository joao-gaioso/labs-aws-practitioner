# Lab 01 — Primeiro Bucket S3

## 🎯 Objetivo

Criar seu primeiro recurso AWS com Terraform. Você vai entender a estrutura básica de um projeto Terraform e os comandos fundamentais.

## 📁 Estrutura dos arquivos

```
lab-01-primeiro-s3/
├── versions.tf   → versões fixadas do Terraform e providers
├── provider.tf   → configuração do provider AWS (região, tags padrão)
├── main.tf       → recursos que serão criados
└── outputs.tf    → informações exibidas após o apply
```

> 💡 Separar em arquivos por responsabilidade é uma boa prática. O Terraform lê todos os `.tf` da pasta juntos — a ordem dos arquivos não importa.

## 🧱 O que será criado

- 1 bucket S3 com nome único (gerado automaticamente)
- Bloqueio de acesso público ativado

## 🚀 Executando o lab

```bash
# 1. Inicializar — baixa o provider AWS e o provider random
terraform init

# 2. Ver o plano de execução — nada é criado ainda
terraform plan

# 3. Criar os recursos (digite "yes" quando solicitado)
terraform apply

# 4. Ver os outputs (nome e ARN do bucket)
terraform output
```

## 🔍 Explorando o estado

Após o `apply`, o Terraform cria um arquivo `terraform.tfstate`. Ele guarda o estado atual da infraestrutura.

```bash
# Ver todos os recursos gerenciados pelo Terraform
terraform state list

# Ver detalhes de um recurso específico
terraform state show aws_s3_bucket.meu_primeiro_bucket
```

## 🧹 Destruindo os recursos

```bash
terraform destroy
```

## 💡 Conceitos deste lab

**`terraform init`** — inicializa o projeto, baixa os providers declarados em `versions.tf`.

**`terraform plan`** — mostra o que será criado/alterado/destruído. Nunca aplica nada. Leia sempre antes do apply.

**`terraform apply`** — cria os recursos na AWS. Pede confirmação antes de executar.

**`terraform destroy`** — destrói todos os recursos gerenciados pelo estado atual.

**Provider** — plugin que ensina o Terraform a se comunicar com um serviço (AWS, Azure, GCP, etc.).

**Resource** — um recurso gerenciado pelo Terraform (`aws_s3_bucket`, `aws_instance`, etc.).

**Output** — valor exportado após o apply, como o nome ou ARN de um recurso criado.

**`terraform.tfstate`** — arquivo local que guarda o estado da infraestrutura. Nunca edite manualmente. Em projetos reais, esse arquivo fica em um backend remoto (S3 + DynamoDB).
