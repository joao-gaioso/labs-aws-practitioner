# Lab 07 — Lambda com Python

## 🎯 Objetivo

Criar uma função Lambda Python com Terraform aplicando boas práticas: IAM Role com least
privilege, CloudWatch Log Group explícito com retenção, empacotamento automático do código
e Function URL para invocação HTTP sem precisar de API Gateway.

Ao final deste lab você vai saber:

- O que é Lambda e quando usar
- Como a Lambda recebe permissões via IAM Role
- Como o Terraform empacota e faz deploy do código Python
- Como invocar a Lambda via CLI e via URL
- Como ler os logs no CloudWatch

---

## 📖 Contexto

A LojaFácil precisa de uma funcionalidade simples: um serviço que recebe um nome e devolve
uma saudação personalizada. Esse tipo de lógica pequena, que roda por milissegundos e só é
chamada quando necessário, é o caso de uso perfeito para Lambda.

Em vez de manter um servidor ligado 24h esperando por chamadas, a Lambda executa **só quando
é invocada** e você paga apenas pelo tempo de execução. Sem servidor para provisionar, sem
sistema operacional para atualizar, sem escalabilidade para configurar.

---

## 🏗️ Arquitetura

```
Você (curl / AWS CLI)
        │
        │  HTTPS
        ▼
┌───────────────────────┐
│   Function URL        │  ← endpoint gerado pela AWS, sem API Gateway
│   (authorization=NONE)│
└──────────┬────────────┘
           │  invoca
           ▼
┌───────────────────────┐      ┌─────────────────────────┐
│   Lambda Function     │─────►│  CloudWatch Log Group   │
│   hello_world.py      │      │  /aws/lambda/lab-lambda  │
│   runtime: python3.13 │      │  retenção: 7 dias        │
└──────────┬────────────┘      └─────────────────────────┘
           │  assume
           ▼
┌───────────────────────┐      ┌─────────────────────────┐
│   IAM Role            │      │  X-Ray                  │
│   lab-lambda-role     │      │  traces de latência     │
│   (least privilege)   │      └─────────────────────────┘
└───────────────────────┘
```


---

## 📁 Estrutura dos arquivos

```
lab-07-lambda-python/
├── versions.tf          → versões fixadas (inclui provider archive)
├── provider.tf          → provider AWS com default_tags
├── backend.tf           → backend S3 para o state file
├── variables.tf         → variáveis de entrada
├── main.tf              → IAM role, log group, Lambda, Function URL
├── outputs.tf           → nome, ARN, URL, comandos prontos
└── src/
    └── hello_world.py   → código Python da função
```

> O diretório `.build/` é gerado automaticamente durante o `plan`/`apply`.
> Ele contém o `.zip` empacotado e está no `.gitignore`.

---

## 🧱 O que será criado

| Recurso | Nome | Para que serve |
|---|---|---|
| `aws_iam_role` | `lab-lambda-role` | Identidade da Lambda na AWS |
| `aws_iam_role_policy_attachment` | — | Permissão para escrever logs |
| `aws_cloudwatch_log_group` | `/aws/lambda/lab-lambda-function` | Logs com retenção de 7 dias |
| `aws_lambda_function` | `lab-lambda-function` | A função em si |
| `aws_lambda_function_url` | — | Endpoint HTTPS para invocar a Lambda |

---

## 🧠 Entendendo os conceitos antes de criar

Leia esta seção antes de rodar o `terraform apply`. Ela explica o porquê de cada
decisão no código — assim você não está só copiando, está entendendo.

### O que é Lambda?

Lambda é um serviço de computação **serverless**: você sobe o código e a AWS cuida
de tudo — servidor, sistema operacional, escalabilidade, disponibilidade.

Funciona assim:

```
1. Alguém invoca a Lambda (CLI, URL, S3, SQS, API Gateway...)
2. A AWS inicia um container com o seu código (se não tiver um "quente")
3. A função executa e retorna o resultado
4. O container fica em standby por um tempo (warm) ou é encerrado
5. Você paga apenas pelos milissegundos de execução
```

**Quando usar Lambda:**
- Lógica pequena e isolada (validações, transformações, notificações)
- Processamento em resposta a eventos (upload no S3, mensagem no SQS...)
- APIs simples sem estado (junto com API Gateway ou Function URL)
- Tarefas agendadas (com EventBridge)

**Quando NÃO usar Lambda:**
- Processos que rodam continuamente (use ECS ou EC2)
- Tarefas que levam mais de 15 minutos (limite máximo da Lambda)
- Aplicações que precisam de estado local em memória entre invocações


### O que é IAM Role? (e por que a Lambda precisa de uma)

Pense na IAM Role como um **crachá de acesso** dentro da AWS.

Quando a Lambda executa, ela precisa provar pra AWS quem ela é e o que pode fazer.
Sem um crachá, ela não tem permissão de fazer nada — nem escrever seus próprios logs.

A role tem duas partes:

**1. Trust Policy — "quem pode usar este crachá?"**

```json
{
  "Statement": [{
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

Aqui estamos dizendo: "este crachá pode ser usado pelo serviço Lambda da AWS".
Se colocássemos `ec2.amazonaws.com`, uma EC2 poderia usar. Lambda não poderia.

**2. Policy Attachment — "o que este crachá permite fazer?"**

Anexamos a `AWSLambdaBasicExecutionRole`, que permite apenas:
- Criar log streams no CloudWatch
- Escrever eventos de log

Isso é o **princípio do menor privilégio**: a Lambda só pode fazer exatamente o
que precisa. Se ela fosse comprometida por um ataque, o invasor não conseguiria
acessar S3, DynamoDB, ou qualquer outro serviço.

> ⚠️ Um erro comum de iniciantes é usar `AdministratorAccess` para "funcionar logo".
> Isso é extremamente perigoso — daria à Lambda poder total sobre toda a sua conta AWS.

### O que o `archive_file` faz?

A Lambda não aceita um arquivo `.py` diretamente — ela precisa de um `.zip`.

O `data "archive_file"` do Terraform faz esse empacotamento **localmente** na sua
máquina antes de enviar para a AWS:

```
src/hello_world.py  →  (empacota)  →  .build/hello_world.zip  →  upload para AWS
```

É um **data source**, não um resource — ele não cria nada na AWS, só executa uma
operação local. Por isso está no `data "archive_file"` e não no `resource`.

### O que é `source_code_hash` e por que é obrigatório?

Sem `source_code_hash`, o Terraform não consegue detectar que o código Python mudou.

O motivo: o Terraform rastreia o estado pelos **atributos dos recursos**. O `filename`
do `.zip` não muda (é sempre `.build/hello_world.zip`). Então, se você editar o `.py`
e rodar `terraform apply`, o Terraform acha que nada mudou e **não faz novo deploy**.

Com `source_code_hash`, o Terraform calcula o hash SHA256 do `.zip`:
- Código igual → hash igual → sem deploy
- Código diferente → hash diferente → novo deploy ✅

```hcl
source_code_hash = data.archive_file.lambda.output_base64sha256
```

Experimente: edite o `.py`, rode `terraform plan` e procure por `source_code_hash`
no output — você vai ver `(known after apply)` indicando que uma mudança foi detectada.


### O que é Function URL?

É um endpoint HTTPS permanente gerado pela AWS diretamente para a Lambda.

```
https://abc123xyz.lambda-url.us-east-1.on.aws/
```

Antes da Function URL existir (2022), para expor uma Lambda via HTTP você
precisava obrigatoriamente de um API Gateway — um serviço separado com mais
configuração e custo adicional por requisição.

**Comparação:**

| | Function URL | API Gateway |
|---|---|---|
| Configuração | Simples | Complexa |
| Custo extra | Não | Sim (por requisição) |
| Roteamento (`/usuarios`, `/pedidos`) | Não | Sim |
| Autenticação avançada | IAM ou nenhuma | IAM, Cognito, JWT, API Key |
| Quando usar | Testes, webhooks simples | APIs com múltiplas rotas |

Para este lab, Function URL é perfeita: zero configuração adicional e você
consegue testar com `curl` imediatamente após o deploy.

### O que são variáveis de ambiente na Lambda?

São valores que você injeta na função via Terraform — sem colocar no código.

```hcl
environment {
  variables = {
    NOME_PADRAO = var.nome_padrao   # vem do variables.tf
    APP_VERSION = "1.0.0"
  }
}
```

No Python, você lê com `os.environ.get("NOME_PADRAO")`.

**Por que isso é poderoso?**

Imagine que você tem dois ambientes: `dev` e `prod`. O comportamento muda
(nome padrão diferente, versão diferente), mas o código Python é **idêntico**.
Você só altera as variáveis de ambiente no Terraform e faz o deploy.

> ⚠️ Nunca coloque segredos (senhas, tokens, chaves de API) em variáveis de
> ambiente da Lambda — eles ficam visíveis no console AWS. Use o
> **AWS Secrets Manager** ou **SSM Parameter Store** para segredos.

### Por que o `depends_on` na Lambda?

O Terraform cria recursos em paralelo quando possível — para ganhar velocidade.
O problema: a Lambda pode ser criada antes da policy ser anexada à role.
Quando ela é invocada, tenta escrever logs e... falha com erro de permissão.

```hcl
depends_on = [
  aws_iam_role_policy_attachment.lambda_basic,  # policy anexada antes
  aws_cloudwatch_log_group.lambda,              # log group criado antes
]
```

Com `depends_on`, forçamos a ordem: role → policy → log group → Lambda.

---

## 🚀 Deploy

```bash
terraform init
terraform plan
terraform apply
```

Após o apply, copie os outputs — você vai precisar deles:

```bash
terraform output function_name   # nome da função
terraform output function_url    # URL para chamar via curl
terraform output log_group       # nome do log group no CloudWatch
terraform output comando_invoke_cli
terraform output comando_curl
terraform output comando_logs
```


---

## ✅ Como testar a Lambda

Há quatro formas de testar — experimente todas para entender as diferenças.

### Forma 1 — AWS CLI (mais comum no dia a dia)

```bash
aws lambda invoke \
  --function-name $(terraform output -raw function_name) \
  --payload '{"nome":"Ana"}' \
  --cli-binary-format raw-in-base64-out \
  resposta.json && cat resposta.json
```

O resultado vai para `resposta.json`. O `cat` no final já exibe na tela.

Resposta esperada:
```json
{
  "statusCode": 200,
  "headers": {"Content-Type": "application/json"},
  "body": "{\"mensagem\": \"Olá, Ana! Esta é minha primeira Lambda com Terraform.\", \"versao\": \"1.0.0\", \"request_id\": \"abc-123...\"}"
}
```

### Forma 2 — curl via Function URL

```bash
curl -s -X POST "$(terraform output -raw function_url)" \
  -H "Content-Type: application/json" \
  -d '{"nome":"Ana"}'
```

Aqui a resposta já vem direto no terminal, sem arquivo intermediário.

### Forma 3 — Console AWS (visual, ótimo para aprender)

1. Acesse: `https://console.aws.amazon.com/lambda/home#/functions`
2. Clique em `lab-lambda-function`
3. Aba **Test** → botão **Test**
4. Em **Event JSON**, coloque:
   ```json
   { "nome": "Ana" }
   ```
5. Clique em **Test** e veja o resultado expandido com logs, duração e memória usada

### Forma 4 — Logs em tempo real (dois terminais)

**Terminal 1** — fique observando os logs:
```bash
aws logs tail "$(terraform output -raw log_group)" --follow --region us-east-1
```

**Terminal 2** — invoque a Lambda algumas vezes:
```bash
aws lambda invoke \
  --function-name $(terraform output -raw function_name) \
  --payload '{"nome":"Ana"}' \
  --cli-binary-format raw-in-base64-out \
  /dev/null
```

No Terminal 1, você verá os logs aparecendo em tempo real a cada invocação:
```
START RequestId: abc-123...
INFO Evento recebido: {"nome": "Ana"}
INFO Resposta enviada: {"mensagem": "Olá, Ana!...", ...}
END RequestId: abc-123...
REPORT RequestId: abc-123... Duration: 2.45 ms  Billed Duration: 3 ms  Memory Size: 128 MB
```

> 💡 A linha `REPORT` é importante: ela mostra a duração real, a duração faturada
> (arredondada para cima em 1ms) e a memória usada. Para esta função simples, você
> vai ver que ela usa muito menos que os 128 MB alocados.

---

## 🔍 Verificando no console AWS

**Lambda → Function:**
```
https://console.aws.amazon.com/lambda/home#/functions/lab-lambda-function
```
- Aba **Code**: veja o código Python diretamente no console
- Aba **Configuration → Environment variables**: confirme as env vars
- Aba **Configuration → Permissions**: veja a role anexada
- Aba **Monitor**: gráficos de invocações, erros e duração

**IAM Role:**
```
https://console.aws.amazon.com/iam/home#/roles/lab-lambda-role
```
Veja que só tem uma política: `AWSLambdaBasicExecutionRole`. Nada mais.

**CloudWatch Logs:**
```
https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups/log-group/%2Faws%2Flambda%2Flab-lambda-function
```
Clique em um **log stream** para ver os logs de uma invocação específica.

**X-Ray Traces:**
```
https://console.aws.amazon.com/xray/home#/traces
```
Após algumas invocações, você verá os traces com latência detalhada.


---

## 🏆 Desafios

Estes desafios foram criados para você resolver sozinha. Não há um passo a passo —
use o código do lab como referência e pesquise quando precisar. Isso é exatamente
como funciona no trabalho real.

---

### 🥉 Desafio 1 — Adicione a data e hora na resposta

**O que fazer:**

Modifique o `src/hello_world.py` para incluir a data e hora atual na resposta.
A resposta deve ficar assim:

```json
{
  "mensagem": "Olá, Ana! Esta é minha primeira Lambda com Terraform.",
  "versao": "1.0.0",
  "request_id": "abc-123...",
  "timestamp": "2025-06-23T14:30:00.123456"
}
```

**Dicas:**
- O módulo `datetime` já vem com o Python (não precisa instalar nada)
- `from datetime import datetime` e `datetime.now().isoformat()` são seus amigos
- Depois de editar o `.py`, rode `terraform plan` e observe o `source_code_hash`
  aparecer como changed — esse é o Terraform detectando que o código mudou
- Depois rode `terraform apply` para fazer o novo deploy

**Como verificar se funcionou:**
```bash
aws lambda invoke \
  --function-name $(terraform output -raw function_name) \
  --payload '{"nome":"Ana"}' \
  --cli-binary-format raw-in-base64-out \
  resposta.json && cat resposta.json
```

O campo `timestamp` deve aparecer na resposta.

---

### 🥈 Desafio 2 — Adicione uma variável de ambiente `AMBIENTE`

**O que fazer:**

Adicione uma nova variável de ambiente chamada `AMBIENTE` com valor `"desenvolvimento"`.
A resposta da Lambda deve incluir esse valor:

```json
{
  "mensagem": "Olá, Ana! Esta é minha primeira Lambda com Terraform.",
  "versao": "1.0.0",
  "request_id": "abc-123...",
  "ambiente": "desenvolvimento"
}
```

**Você precisará alterar dois arquivos:**

1. `variables.tf` — criar uma nova variável `ambiente`
2. `main.tf` — adicionar `AMBIENTE` no bloco `environment { variables = { ... } }`
3. `src/hello_world.py` — ler `os.environ.get("AMBIENTE")` e incluir na resposta

**Dicas:**
- Siga o mesmo padrão da variável `NOME_PADRAO` que já existe
- O valor padrão pode ser `"desenvolvimento"` mesmo
- Após as mudanças, `terraform plan` mostrará dois changes: o código Python e
  as variáveis de ambiente da Lambda

**Como verificar se funcionou:**

Invoque via CLI e confirme que `"ambiente": "desenvolvimento"` está na resposta.

Depois, tente mudar o valor para `"producao"` no `variables.tf`, aplicar novamente
e ver a resposta mudar **sem alterar uma linha de Python**.

---

### 🥇 Desafio 3 — Valide a entrada e retorne erro se o nome for vazio

**O que fazer:**

Atualmente, se você enviar `{"nome": ""}` (string vazia), a Lambda retorna:
```json
{"mensagem": "Olá, ! Esta é minha primeira Lambda com Terraform."}
```

Isso é um bug. Corrija o `hello_world.py` para que, quando `nome` vier como
string vazia, a Lambda retorne um erro com `statusCode 400`:

```json
{
  "statusCode": 400,
  "headers": {"Content-Type": "application/json"},
  "body": "{\"erro\": \"O campo 'nome' não pode ser vazio.\"}"
}
```

Quando `nome` vier preenchido corretamente, o comportamento deve continuar igual
(`statusCode 200` com a saudação).

**Dicas:**
- No Python, `""` é considerado `False` em um `if` — então `if not nome:` funciona
- O `statusCode` faz parte do dicionário de retorno da função, não é um erro Python
- Não use `raise Exception` — Lambda pode retornar erros de forma controlada pelo `statusCode`
- Lembre de fazer o redeploy com `terraform apply` após alterar o `.py`

**Como verificar se funcionou:**

Teste com nome válido (deve retornar 200):
```bash
aws lambda invoke \
  --function-name $(terraform output -raw function_name) \
  --payload '{"nome":"Ana"}' \
  --cli-binary-format raw-in-base64-out \
  resposta.json && cat resposta.json
```

Teste com nome vazio (deve retornar 400):
```bash
aws lambda invoke \
  --function-name $(terraform output -raw function_name) \
  --payload '{"nome":""}' \
  --cli-binary-format raw-in-base64-out \
  resposta.json && cat resposta.json
```

Teste sem passar nome (deve usar `NOME_PADRAO` e retornar 200):
```bash
aws lambda invoke \
  --function-name $(terraform output -raw function_name) \
  --payload '{}' \
  --cli-binary-format raw-in-base64-out \
  resposta.json && cat resposta.json
```

> 💡 Perceba que retornar `statusCode 400` não é um erro da Lambda em si — ela
> executou com sucesso e retornou uma resposta controlada. O `statusCode` é um
> campo que você define no retorno, seguindo a convenção HTTP.


---

## 💡 Resumo dos conceitos

| Conceito | O que é | Por que importa |
|---|---|---|
| **IAM Role** | Identidade/crachá da Lambda na AWS | Sem ela, a Lambda não tem permissão de nada |
| **Trust Policy** | Define quem pode usar a role | Garante que só Lambda (não EC2, humanos, etc) usa essa role |
| **Least Privilege** | Só dar o mínimo necessário | Se a Lambda for comprometida, o dano é limitado |
| **`archive_file`** | Empacota `.py` em `.zip` localmente | Lambda não aceita código bruto, só `.zip` |
| **`source_code_hash`** | Hash do `.zip` para detectar mudanças | Sem ele, editar o Python não gera novo deploy |
| **`depends_on`** | Força ordem de criação | Evita race condition entre role, policy e Lambda |
| **Log Group explícito** | Terraform gerencia o log group | Controla retenção e apaga com `destroy` |
| **Variáveis de ambiente** | Config injetada sem alterar código | Mesmo código, comportamentos diferentes por ambiente |
| **Function URL** | Endpoint HTTPS direto para a Lambda | Testa sem precisar de API Gateway |
| **X-Ray** | Rastreamento de latência | Debugging e análise de performance |

---

## ⚠️ Boas práticas aplicadas neste lab

| Prática | Onde está no código |
|---|---|
| Least privilege | `AWSLambdaBasicExecutionRole` — nada mais |
| Log group com retenção | `retention_in_days = var.log_retention_days` |
| Detecção de mudança no código | `source_code_hash = data.archive_file.lambda.output_base64sha256` |
| Ordem de criação garantida | `depends_on` na `aws_lambda_function` |
| Rastreamento de performance | `tracing_config { mode = "Active" }` |
| Sem segredos no código | `os.environ.get(...)` em vez de strings hardcoded |
| Tags em todos os recursos | `default_tags` no `provider.tf` |
| Versões fixadas | `versions.tf` com `~> 5.0` e `~> 2.0` |
| Sem região hardcoded | `var.aws_region` em todos os lugares |

---

## ❓ Dúvidas frequentes

**"Por que criar o log group explicitamente se a Lambda cria sozinha?"**

A Lambda cria o log group automaticamente na primeira invocação, mas sem retenção
definida. Os logs ficam armazenados para sempre e geram custo crescente. Criando
explicitamente, você define a retenção desde o início e o `terraform destroy` apaga
tudo junto.

**"O que acontece se eu não colocar `source_code_hash`?"**

Você edita o `.py`, roda `terraform apply` e... nada acontece. O Terraform não
detecta a mudança porque o caminho do arquivo (`.build/hello_world.zip`) não mudou.
A Lambda continua rodando o código antigo silenciosamente.

**"Por que `authorization_type = "NONE"` na Function URL?"**

Para simplificar o lab — você chama com `curl` sem precisar passar credenciais AWS.
Em produção use `"AWS_IAM"`:
```hcl
authorization_type = "AWS_IAM"
```
Assim, só quem tiver permissão `lambda:InvokeFunctionUrl` na IAM consegue chamar.

**"A Lambda pode acessar S3, DynamoDB, outros serviços?"**

Sim — mas você precisa anexar políticas adicionais à role. Neste lab, a role só tem
`AWSLambdaBasicExecutionRole` (logs). Nos próximos labs você vai adicionar permissões
conforme necessário, sempre seguindo o least privilege.

**"O que é o `request_id` na resposta?"**

É o identificador único de cada invocação, gerado pela AWS (`context.aws_request_id`).
Útil para correlacionar a resposta com os logs no CloudWatch — procure esse ID nos
logs para ver exatamente o que aconteceu naquela chamada específica.

---

## 🧹 Destruindo os recursos

```bash
terraform destroy
```

Todos os recursos são removidos: Lambda, IAM Role, Function URL e o CloudWatch Log Group
(incluindo os logs armazenados).
