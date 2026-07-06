#!/bin/bash

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

REGION="us-east-1"
BUCKET_NAME="lab-pedidos-$(date +%s)"
TOPIC_NAME="lab-pedidos-topic"
QUEUE_NAME="lab-pedidos-queue"
TABLE_NAME="lab-pedidos"
LAMBDA_NAME="lambda-processa-pedidos"
ROLE_NAME="LambdaPedidosRole"
ZIP_FILE="lambda.zip"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   INICIANDO DEPLOY LAB S3-SNS-SQS-LAMBDA  ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

echo -e "${BLUE}[INFO]${NC} Região:         ${YELLOW}$REGION${NC}"
echo -e "${BLUE}[INFO]${NC} Bucket S3:      ${YELLOW}$BUCKET_NAME${NC}"
echo -e "${BLUE}[INFO]${NC} Tópico SNS:     ${YELLOW}$TOPIC_NAME${NC}"
echo -e "${BLUE}[INFO]${NC} Fila SQS:       ${YELLOW}$QUEUE_NAME${NC}"
echo -e "${BLUE}[INFO]${NC} Tabela DynamoDB:${YELLOW}$TABLE_NAME${NC}"
echo -e "${BLUE}[INFO]${NC} Lambda:         ${YELLOW}$LAMBDA_NAME${NC}"
echo ""

# ─── STEP 1: Verificar lambda.zip ────────────────────────────────────────────
echo -e "${YELLOW}[STEP 1/11]${NC} Verificando lambda.zip..."

if [ ! -f "$ZIP_FILE" ]; then
  echo -e "${RED}[ERRO]${NC} $ZIP_FILE não encontrado!"
  echo -e "${YELLOW}[DICA]${NC} Windows PowerShell:"
  echo -e "${YELLOW}        Compress-Archive -Path lambda_function.py -DestinationPath lambda.zip -Force${NC}"
  echo -e "${YELLOW}[DICA]${NC} Linux/Mac:"
  echo -e "${YELLOW}        zip lambda.zip lambda_function.py${NC}"
  exit 1
fi
echo -e "${GREEN}[OK]${NC} lambda.zip encontrado"
echo ""

# ─── STEP 2: Obter Account ID ────────────────────────────────────────────────
echo -e "${YELLOW}[STEP 2/11]${NC} Obtendo Account ID..."

ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)

echo -e "${GREEN}[OK]${NC} Account ID: ${YELLOW}$ACCOUNT_ID${NC}"
echo ""

# ─── STEP 3: Criar bucket S3 ─────────────────────────────────────────────────
echo -e "${YELLOW}[STEP 3/11]${NC} Criando bucket S3..."

if aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Bucket criado: ${YELLOW}$BUCKET_NAME${NC}"
else
  echo -e "${RED}[ERRO]${NC} Falha ao criar bucket S3"
  exit 1
fi
echo ""

# ─── STEP 4: Criar tópico SNS ────────────────────────────────────────────────
echo -e "${YELLOW}[STEP 4/11]${NC} Criando tópico SNS..."

TOPIC_ARN=$(aws sns create-topic \
  --name $TOPIC_NAME \
  --region $REGION \
  --query 'TopicArn' \
  --output text)

echo -e "${GREEN}[OK]${NC} Tópico SNS criado: ${YELLOW}$TOPIC_ARN${NC}"
echo ""

# ─── STEP 5: Criar fila SQS ──────────────────────────────────────────────────
echo -e "${YELLOW}[STEP 5/11]${NC} Criando fila SQS..."

QUEUE_URL=$(aws sqs create-queue \
  --queue-name $QUEUE_NAME \
  --region $REGION \
  --attributes VisibilityTimeout=90 \
  --query 'QueueUrl' \
  --output text 2>/dev/null || \
  aws sqs get-queue-url \
    --queue-name $QUEUE_NAME \
    --region $REGION \
    --query 'QueueUrl' \
    --output text)

QUEUE_ARN="arn:aws:sqs:$REGION:$ACCOUNT_ID:$QUEUE_NAME"

echo -e "${GREEN}[OK]${NC} Fila SQS: ${YELLOW}$QUEUE_URL${NC}"
echo ""

# ─── STEP 6: Permitir que o SNS publique na fila SQS ─────────────────────────
echo -e "${YELLOW}[STEP 6/11]${NC} Configurando permissão SNS -> SQS..."

cat > sqs-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "$QUEUE_ARN",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "$TOPIC_ARN"
        }
      }
    }
  ]
}
EOF

# Gera attributes.json com Policy como string JSON escapada (formato exigido pelo CLI)
python3 -c "
import json
policy = json.load(open('sqs-policy.json'))
attrs = {'Policy': json.dumps(policy)}
json.dump(attrs, open('sqs-attributes.json', 'w'))
"

aws sqs set-queue-attributes \
  --queue-url $QUEUE_URL \
  --attributes file://sqs-attributes.json \
  --region $REGION

echo -e "${GREEN}[OK]${NC} Permissão SNS -> SQS configurada"
echo ""

# ─── STEP 7: Inscrever a fila SQS no tópico SNS ──────────────────────────────
echo -e "${YELLOW}[STEP 7/11]${NC} Inscrevendo SQS no tópico SNS..."

aws sns subscribe \
  --topic-arn $TOPIC_ARN \
  --protocol sqs \
  --notification-endpoint $QUEUE_ARN \
  --region $REGION > /dev/null

echo -e "${GREEN}[OK]${NC} SQS inscrito no SNS"
echo ""

# ─── STEP 8: Permitir que o S3 publique no tópico SNS ────────────────────────
echo -e "${YELLOW}[STEP 8/11]${NC} Configurando permissão S3 -> SNS..."

aws sns set-topic-attributes \
  --topic-arn $TOPIC_ARN \
  --attribute-name Policy \
  --attribute-value "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Principal\": { \"Service\": \"s3.amazonaws.com\" },
      \"Action\": \"sns:Publish\",
      \"Resource\": \"$TOPIC_ARN\",
      \"Condition\": {
        \"ArnLike\": { \"aws:SourceArn\": \"arn:aws:s3:::$BUCKET_NAME\" }
      }
    }]
  }" \
  --region $REGION

echo -e "${GREEN}[OK]${NC} Permissão S3 -> SNS configurada"
echo ""

# ─── STEP 9: Configurar notificação S3 -> SNS ────────────────────────────────
echo -e "${YELLOW}[STEP 9/11]${NC} Configurando notificação S3 -> SNS..."

cat > s3-notification.json <<EOF
{
  "TopicConfigurations": [
    {
      "TopicArn": "$TOPIC_ARN",
      "Events": ["s3:ObjectCreated:Put"],
      "Filter": {
        "Key": {
          "FilterRules": [
            { "Name": "suffix", "Value": ".json" }
          ]
        }
      }
    }
  ]
}
EOF

aws s3api put-bucket-notification-configuration \
  --bucket $BUCKET_NAME \
  --notification-configuration file://s3-notification.json

echo -e "${GREEN}[OK]${NC} Notificação S3 -> SNS configurada (filtro: *.json)"
echo ""

# ─── STEP 10: Criar tabela DynamoDB ──────────────────────────────────────────
echo -e "${YELLOW}[STEP 10/11]${NC} Criando tabela DynamoDB..."

if aws dynamodb create-table \
  --table-name $TABLE_NAME \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Tabela DynamoDB criada: ${YELLOW}$TABLE_NAME${NC}"
else
  echo -e "${YELLOW}[AVISO]${NC} Tabela DynamoDB já existe"
fi
echo ""

# ─── STEP 11: Criar IAM Role + Lambda + Trigger SQS ─────────────────────────
echo -e "${YELLOW}[STEP 11/11]${NC} Criando IAM Role, Lambda e trigger SQS..."

# Trust policy
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

if aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://trust-policy.json 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} IAM Role criada"
else
  echo -e "${YELLOW}[AVISO]${NC} IAM Role já existe"
fi

# Policies
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess 2>/dev/null || true

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess 2>/dev/null || true

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonSQSFullAccess 2>/dev/null || true

echo -e "${BLUE}[INFO]${NC} Aguardando propagação IAM (15s)..."
sleep 15

ROLE_ARN=$(aws iam get-role \
  --role-name $ROLE_NAME \
  --query 'Role.Arn' \
  --output text)

echo -e "${BLUE}[INFO]${NC} Role ARN: ${YELLOW}$ROLE_ARN${NC}"

# Criar Lambda
if aws lambda create-function \
  --function-name $LAMBDA_NAME \
  --runtime python3.12 \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://$ZIP_FILE \
  --role $ROLE_ARN \
  --timeout 60 \
  --memory-size 256 \
  --environment "Variables={TABLE_NAME=$TABLE_NAME}" \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Lambda criada com sucesso"
else
  echo -e "${YELLOW}[AVISO]${NC} Lambda já existe, atualizando código..."
  aws lambda update-function-code \
    --function-name $LAMBDA_NAME \
    --zip-file fileb://$ZIP_FILE \
    --region $REGION > /dev/null
  echo -e "${GREEN}[OK]${NC} Lambda atualizada"
fi

# Aguardar Lambda ficar ativa
sleep 5

# Trigger SQS -> Lambda
if aws lambda create-event-source-mapping \
  --function-name $LAMBDA_NAME \
  --event-source-arn $QUEUE_ARN \
  --batch-size 10 \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Trigger SQS -> Lambda configurado"
else
  echo -e "${YELLOW}[AVISO]${NC} Trigger já existe"
fi
echo ""

# ─── Resumo final ─────────────────────────────────────────────────────────────
echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}   DEPLOY FINALIZADO COM SUCESSO! 🚀       ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${BLUE}[ARQUITETURA CRIADA]${NC}"
echo -e "  S3 (upload .json) → SNS → SQS → Lambda → DynamoDB"
echo ""
echo -e "${BLUE}[BUCKET S3]${NC}"
echo -e "  ${YELLOW}$BUCKET_NAME${NC}"
echo ""
echo -e "${BLUE}[TESTE - Enviar arquivo de pedidos]${NC}"
echo -e "${YELLOW}  aws s3 cp pedidos.json s3://$BUCKET_NAME/pedidos.json${NC}"
echo ""
echo -e "${BLUE}[VERIFICAR LOGS DA LAMBDA]${NC}"
echo -e "${YELLOW}  aws logs tail /aws/lambda/$LAMBDA_NAME --follow --region $REGION${NC}"
echo ""
echo -e "${BLUE}[CONSULTAR PEDIDOS NO DYNAMODB]${NC}"
echo -e "${YELLOW}  aws dynamodb scan --table-name $TABLE_NAME --region $REGION${NC}"
echo ""
echo -e "${BLUE}[SALVAR NOME DO BUCKET PARA O CLEANUP]${NC}"
echo -e "${YELLOW}  Edite o cleanup.sh e defina: BUCKET_NAME=\"$BUCKET_NAME\"${NC}"
echo ""
