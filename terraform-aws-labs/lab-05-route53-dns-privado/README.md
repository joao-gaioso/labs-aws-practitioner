# Lab 05 — Route 53: DNS Privado

## 🎯 Objetivo

Entender como o Route 53 funciona criando uma Hosted Zone privada e registros DNS que apontam para uma EC2. Você vai ver na prática como um nome como `app.lojafacil.internal` resolve para um IP — e o que acontece quando você muda as configurações.

---

## 📖 Contexto

A LojaFácil tem vários servidores internos na AWS. Em vez de os desenvolvedores decorarem IPs como `172.31.45.12`, eles usam nomes como `app.lojafacil.internal`. Quando um servidor é substituído e o IP muda, basta atualizar o DNS — os desenvolvedores continuam usando o mesmo nome.

Esse é o papel do Route 53: traduzir nomes em IPs.

---

## 🏗️ Arquitetura

```
Você (via SSH)
      │
      ▼
EC2 (nginx) ──── IP privado: 172.31.x.x
      ↑
Route 53 Record A
  app.lojafacil.internal → 172.31.x.x
      ↑
Hosted Zone Privada
  lojafacil.internal
      ↑
VPC padrão da conta
```

> 💡 A Hosted Zone é **privada** — o nome `app.lojafacil.internal` só resolve dentro da VPC. De fora da AWS, esse nome não existe.

---

## 📁 Estrutura dos arquivos

```
lab-05-route53-dns-privado/
├── versions.tf   → versões fixadas
├── provider.tf   → provider AWS
├── variables.tf  → variáveis (incluindo dns_ttl para os experimentos)
├── main.tf       → EC2, Security Group, Hosted Zone, registros DNS
└── outputs.tf    → IPs, nome DNS, comando SSH e de teste
```

---

## 🚀 Deploy inicial

```bash
terraform init
terraform plan
terraform apply
```

Após o apply, anote os outputs — você vai precisar deles nos testes:

```bash
terraform output comando_ssh       # comando para conectar na EC2
terraform output dominio_app       # nome DNS criado
terraform output ip_privado_ec2    # IP para comparar com o DNS
```

---

##  Verificação básica

Antes de começar os experimentos, confirme que tudo está funcionando.

### 1. Conecte na EC2 via SSH

```bash
# O comando completo já aparece no output
ssh -i lojafacil-key.pem ec2-user@<IP_PUBLICO>
```

### 2. Dentro da EC2, teste a resolução DNS

```bash
# Deve retornar a página do nginx com "Bem-vinda ao lab Route 53!"
curl http://app.lojafacil.internal

# Deve mostrar o IP privado da EC2
dig app.lojafacil.internal +short
```

### 3. Compare o IP retornado pelo DNS com o IP da EC2

```bash
# IP privado da instância
hostname -I
```

Os dois devem ser iguais. Se sim, o DNS está funcionando corretamente. 

---
