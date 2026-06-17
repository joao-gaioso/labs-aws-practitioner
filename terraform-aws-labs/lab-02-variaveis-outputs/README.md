# Lab 02 — Variáveis, Locals e Outputs

## Objetivo

Aprender a parametrizar o código Terraform com variáveis, evitar repetição com `locals` e `for_each`, e exportar informações com outputs.

## 📁 Estrutura dos arquivos

```
lab-02-variaveis-outputs/
├── versions.tf        → versões fixadas
├── provider.tf        → provider AWS usando variáveis
├── variables.tf       → declaração das variáveis de entrada
├── locals.tf          → valores calculados internamente
├── main.tf            → recursos (3 buckets S3 com for_each)
├── outputs.tf         → informações exportadas
└── terraform.tfvars   → valores das variáveis para este ambiente
```

## O que será criado

- 3 buckets S3: `uploads`, `backups`, `logs`
- Todos com bloqueio de acesso público
- Nomes compostos por: `{projeto}-{ambiente}-{funcao}-{account_id}`

## Executando o lab

```bash
terraform init
terraform plan
terraform apply
```

---

## 🧪 Experimentos

Cada experimento abaixo envolve editar diretamente um arquivo `.tf`, rodar `terraform apply` e observar o que muda. Leia o objetivo antes de começar.

---

### Experimento 1 — Alterar o nome do projeto (fácil)

**Objetivo:** entender que variáveis mudam o comportamento de todos os recursos de uma vez.

**O que fazer:**

Abra o `terraform.tfvars` e altere o valor de `projeto`:

```hcl
# De:
projeto = "lab-ana"

# Para:
projeto = "minha-loja"
```

Salve e aplique:

```bash
terraform plan
```

> ⚠️ Antes de confirmar: observe o plano com atenção. O Terraform vai **destruir os 3 buckets antigos e criar 3 novos** porque o nome mudou. Isso é importante — em produção, renomear recursos pode causar indisponibilidade.

Confirme com `terraform apply` e verifique os outputs:

```bash
terraform output nomes_dos_buckets
# Deve mostrar os novos nomes com "minha-loja"
```

**Pergunta para refletir:** por que o Terraform destrói e recria os buckets em vez de só renomeá-los?

---

### Experimento 2 — Adicionar um output novo (fácil)

**Objetivo:** aprender a criar outputs e usar funções built-in do Terraform.

**O que fazer:**

Abra o `outputs.tf` e **descomente** o bloco do Experimento 2:

```hcl
output "total_de_buckets" {
  description = "Quantos buckets foram criados"
  value       = length(aws_s3_bucket.buckets)
}
```

Aplique:

```bash
terraform apply
terraform output total_de_buckets
# Deve retornar: 3
```

Agora, abra o `terraform.tfvars` e adicione um quarto bucket à lista:

```hcl
buckets = ["uploads", "backups", "logs", "relatorios"]
```

Aplique novamente e veja o output mudar:

```bash
terraform apply
terraform output total_de_buckets
# Deve retornar: 4
```

**Pergunta para refletir:** o que acontece se você remover um bucket da lista que já foi criado? Rode o `plan` antes de aplicar e leia o que o Terraform pretende fazer.

---

### Experimento 3 — Funções em locals (fácil)

**Objetivo:** conhecer funções built-in do Terraform e o operador ternário.

**O que fazer:**

Abra o `locals.tf` e **descomente** as duas linhas dentro do bloco `locals`:

```hcl
prefixo_upper  = upper(local.prefixo)
ambiente_label = var.environment == "prod" ? "PRODUCAO" : "NAO-PRODUCAO"
```

Depois abra o `outputs.tf` e **descomente** o bloco do Experimento 3:

```hcl
output "prefixo_maiusculo" { ... }
output "label_ambiente"    { ... }
```

Aplique e veja os novos outputs:

```bash
terraform apply
terraform output prefixo_maiusculo
# "LAB-ANA-DEV"

terraform output label_ambiente
# "NAO-PRODUCAO"
```

Agora altere o `terraform.tfvars` para simular produção:

```hcl
environment = "prod"
```

Aplique novamente:

```bash
terraform apply
terraform output label_ambiente
# "PRODUCAO"
```

> ⚠️ Lembre de voltar para `"dev"` antes de continuar os experimentos.

**O que você usou:**
- `upper(texto)` — transforma em maiúsculas
- `var.x == "y" ? "sim" : "não"` — operador ternário (se/senão)

---

### Experimento 4 — Ativar versionamento com variável booleana (médio)

**Objetivo:** aprender variáveis do tipo `bool` e como elas controlam comportamento de recursos.

**O que fazer:**

**Passo 1:** abra o `variables.tf` e descomente a variável `versioning_enabled`:

```hcl
variable "versioning_enabled" {
  description = "Ativa ou desativa o versionamento nos buckets S3"
  type        = bool
  default     = false
}
```

**Passo 2:** abra o `main.tf` e descomente o bloco `aws_s3_bucket_versioning`.

**Passo 3:** aplique com versionamento desativado (default):

```bash
terraform apply
```

Verifique no console AWS: S3 → seu bucket → Properties → Bucket Versioning → deve estar **Suspended**.

**Passo 4:** ative o versionamento alterando o `terraform.tfvars`:

```hcl
versioning_enabled = true
```

Aplique novamente:

```bash
terraform apply
```

Verifique novamente no console — agora deve estar **Enabled**.

**Passo 5:** tente desativar de volta:

```hcl
versioning_enabled = false
```

```bash
terraform apply
```

> 💡 Observe que o versionamento vai para **Suspended**, não para **Disabled**. Uma vez ativado o versionamento no S3, ele nunca pode ser completamente desligado — apenas suspenso. O Terraform reflete esse comportamento da AWS.

---

## 💡 Conceitos deste lab

**`variable`** — entrada parametrizável com `default`, `type` e `validation`.

**`locals`** — valores calculados internamente. Centralize lógica de nomenclatura aqui.

**`for_each`** — cria múltiplos recursos a partir de uma lista. Cada instância identificada por `each.key`.

**`data source`** — lê informações existentes na AWS sem criar nada.

**`terraform.tfvars`** — arquivo carregado automaticamente com valores das variáveis.

**`merge()`** — combina dois mapas de tags.

**`upper()`, `length()`** — funções built-in do Terraform para transformar valores.

**Operador ternário** — `condição ? valor_se_verdadeiro : valor_se_falso`

## 🧹 Destruindo os recursos

```bash
terraform destroy
```

---

## 🏆 Desafio Final — Remote State no S3

Até agora o `terraform.tfstate` ficou salvo na sua máquina local. Isso funciona para labs, mas em times reais é um problema sério: se duas pessoas rodarem o Terraform ao mesmo tempo, os estados ficam diferentes e a infraestrutura quebra.

A solução é guardar o state em um **backend remoto** — e o mais comum na AWS é um bucket S3.

```
Sua máquina
    │
    ▼
terraform apply
    │
    ├── lê/escreve estado ──► S3 (terraform.tfstate)
```

---

### 📋 O que você precisa fazer

**Passo 1 — Crie o bucket de estado via AWS Console ou AWS CLI**

- Bucket *privado*

**Passo 2 — Crie o arquivo `backend.tf` na pasta do lab**

```hcl
# backend.tf
# Define onde o Terraform vai guardar o arquivo de estado.
# O backend não aceita variáveis — os valores precisam ser literais.

terraform {
  backend "s3" {
    bucket         = "NOME-DO-SEU-BUCKET"
    key            = "lab-02/terraform.tfstate"
    region         = "us-east-1"
  }
}
```

> O campo `key` é o caminho do arquivo dentro do bucket — use um por lab para não sobrescrever estados de outros labs.

**Passo 3 — Reinicialize o Terraform para migrar o estado local para o S3**

```bash
terraform init
```

O Terraform vai detectar que o backend mudou e perguntar se quer migrar o estado local:

```
Do you want to copy existing state to the new backend?
  Only 'yes' will be accepted.

Enter a value: yes
```

Digite `yes`. O `terraform.tfstate` local será copiado para o S3 e o arquivo local ficará vazio.

**Passo 4 — Confirme que funcionou**

```bash
# Rode qualquer comando — o estado agora vem do S3
terraform plan

# Verifique o arquivo no S3
aws s3 ls s3://NOME-DO-SEU-BUCKET/lab-02/
# Deve mostrar o terraform.tfstate
```

Abra o console AWS → S3 → seu bucket de estado → `lab-02/terraform.tfstate` — você vai ver o arquivo com todos os recursos do lab.

---

### Critérios de aceite do desafio

- [ ] `terraform init` migrou o estado local para o S3 sem erros
- [ ] `terraform plan` mostra `No changes` (estado remoto está sincronizado)
- [ ] O arquivo `lab-02/terraform.tfstate` aparece no bucket S3 no console
- [ ] O bucket de estado tem versionamento ativado

---

### 💡 Por que o backend não aceita variáveis?

Você deve ter reparado que no `backend.tf` os valores são literais — não dá para usar `var.aws_region` ou `local.prefixo`. Isso é uma limitação do Terraform: o backend é inicializado antes das variáveis serem resolvidas.

---

### 🧹 Limpeza do desafio

Ao destruir os recursos do lab, o estado no S3 **não é apagado automaticamente** — ele é um recurso separado.

```bash
# Destruir os recursos do lab
terraform destroy

# Apagar o state do S3 manualmente (opcional)
aws s3 rm s3://NOME-DO-SEU-BUCKET/lab-02/terraform.tfstate
```