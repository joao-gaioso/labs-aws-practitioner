# Lab: SQS Lambda Dynamodb

## 📋 Descrição

Este lab demonstra uma arquitetura serverless usando **Amazon SQS + AWS Lambda + Amazon DynamoDB** para processar dados de forma assíncrona e escalável.

### Arquitetura

```
SQS (Fila) → Lambda (Processador) → DynamoDB (Armazenamento)
```

### Fluxo de Funcionamento

1. Mensagens com dados são enviadas para uma fila SQS
2. A fila SQS dispara automaticamente a função Lambda
3. A Lambda processa as mensagens em lote (até 10 por vez)
4. Os dados são salvos na tabela DynamoDB com ID único e timestamp
5. Logs detalhados são gerados no CloudWatch

---

## 🚀 Pré-requisitos

- AWS CLI configurado com credenciais válidas
- Permissões IAM para criar recursos (Lambda, IAM, SQS, DynamoDB)
- Bash shell (Linux/Mac) ou Git Bash (Windows)
- Python 3.12 (para desenvolvimento local - opcional)

---

## 📦 Deploy

### 1. Criar o pacote Lambda

**Windows (PowerShell):**
```powershell
Compress-Archive -Path lambda_function.py -DestinationPath lambda.zip -Force
```

**Linux/Mac:**
```bash
zip lambda.zip lambda_function.py
```

### 2. Executar o deploy

```bash
chmod +x deploy.sh
./deploy.sh
```

O script irá:
- ✅ Criar fila SQS `fila`
- ✅ Criar tabela DynamoDB `Tabela`
- ✅ Criar IAM Role com permissões necessárias
- ✅ Criar função Lambda `lambda-function`
- ✅ Configurar trigger SQS → Lambda

**Tempo estimado:** ~30 segundos

---

## 🧪 Testando o Lab

### Teste 1: Enviar uma mensagem única

```bash
aws sqs send-message --queue-url "https://sqs.us-east-1.amazonaws.com/619425981855/lab-ana" --message-body '{"produto":"Mouse","quantidade":5,"preco":50,"cliente":"Maria Santos"}' --region us-east-1
```

### Teste 2: Enviar múltiplas mensagens

```bash
./teste.sh
```

### Teste 3: Enviar lote de mensagens (mais eficiente)

```bash
# se quiser adicione mais itens dentro do arquivo batch.json

aws sqs send-message-batch --queue-url "https://sqs.us-east-1.amazonaws.com/619425981855/lab-ana" --entries file://batch.json --region us-east-1
```

---

## 🔍 Verificando os Resultados

### 1. Verificar logs da Lambda

Acesse o **AWS Console** → **CloudWatch** → **Log groups** → `/aws/lambda/nomedasualambda`

**Saída esperada nos logs:**
```
2024-01-15T10:30:45.123 INFO Evento recebido: {...}
2024-01-15T10:30:45.234 INFO Processando mensagem: {...}
2024-01-15T10:30:45.456 INFO Processamento finalizado. Total: 1, Erros: 0
```

### 2. Consultar dados no DynamoDB no console ou via aws cli

**Listar todos os itens:**
```bash
aws dynamodb scan --table-name Tabela --region us-east-1
```

**Consultar item específico:**
```bash
aws dynamodb get-item \
  --table-name Tabela \
  --key '{"id":{"S":"SEU_ID_AQUI"}}' \
  --region us-east-1
```

**Contar total de itens:**
```bash
aws dynamodb scan \
  --table-name Tabela \
  --select COUNT \
  --region us-east-1
```

### 3. Verificar métricas da fila SQS

```bash
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/SEU_ACCOUNT_ID/fila \
  --attribute-names All
```

**Métricas importantes:**
- `ApproximateNumberOfMessages`: Mensagens aguardando processamento
- `ApproximateNumberOfMessagesNotVisible`: Mensagens sendo processadas
- `ApproximateNumberOfMessagesDelayed`: Mensagens com delay

---

## 📊 Estrutura dos Dados

### Mensagem SQS (Input)
```json
{
  "produto": "Notebook",
  "quantidade": 2,
  "preco": 3500,
  "cliente": "João Silva"
}
```

### Item DynamoDB (Output)
```json
{
  "id": "abc-123-def-456",
  "data_processamento": "2024-01-15T10:30:45.123456",
  "message_id": "msg-789-xyz-012",
  "status": "processado"
}
```

---

## 🎯 Casos de Uso

Este padrão arquitetural é ideal para:

-  **Processamento assíncrono de dados**
-  **Desacoplamento de sistemas**
-  **Integração entre microserviços**
-  **Buffer para picos de tráfego**
-  **Processamento em lote**
-  **Retry automático de falhas**

---

## 🧹 Limpeza

Para remover todos os recursos criados:

```bash
chmod +x cleanup.sh
./cleanup.sh
```

**⚠️ ATENÇÃO:** Todos os dados serão apagados permanentemente!

---

## 📚 Recursos Adicionais

### Documentação AWS
- [Amazon SQS](https://docs.aws.amazon.com/sqs/)
- [AWS Lambda](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html)
- [Amazon DynamoDB](https://docs.aws.amazon.com/dynamodb/)