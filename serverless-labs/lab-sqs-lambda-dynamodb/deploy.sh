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
QUEUE_NAME="lab-ana"
TABLE_NAME="lab-ana"
LAMBDA_NAME="lambda-lab-ana"
ROLE_NAME="SqsLambdaDynamodbLambdaRole"
ZIP_FILE="lambda.zip"

echo -e "${CYAN}=======================================${NC}"
echo -e "${CYAN}   INICIANDO DEPLOY LAB SQS LAMBDA DYNAMODB${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""

echo -e "${BLUE}[INFO]${NC} Região: ${YELLOW}$REGION${NC}"
echo -e "${BLUE}[INFO]${NC} Fila SQS: ${YELLOW}$QUEUE_NAME${NC}"
echo -e "${BLUE}[INFO]${NC} Tabela DynamoDB: ${YELLOW}$TABLE_NAME${NC}"
echo -e "${BLUE}[INFO]${NC} Lambda: ${YELLOW}$LAMBDA_NAME${NC}"
echo ""

echo -e "${YELLOW}[STEP 1/9]${NC} Verificando lambda.zip..."

if [ ! -f "$ZIP_FILE" ]; then
  echo -e "${RED}[ERRO]${NC} $ZIP_FILE não encontrado!"
  echo -e "${YELLOW}[DICA]${NC} Crie o arquivo com: Compress-Archive -Path lambda_function.py -DestinationPath lambda.zip -Force"
  exit 1
fi
echo -e "${GREEN}[OK]${NC} lambda.zip encontrado"
echo ""

echo -e "${YELLOW}[STEP 2/9]${NC} Criando fila SQS..."

QUEUE_URL=$(aws sqs create-queue \
  --queue-name $QUEUE_NAME \
  --region $REGION \
  --query 'QueueUrl' \
  --output text 2>/dev/null || echo "")

if [ -n "$QUEUE_URL" ]; then
  echo -e "${GREEN}[OK]${NC} Fila SQS criada: ${YELLOW}$QUEUE_URL${NC}"
else
  QUEUE_URL=$(aws sqs get-queue-url \
    --queue-name $QUEUE_NAME \
    --region $REGION \
    --query 'QueueUrl' \
    --output text)
  echo -e "${YELLOW}[AVISO]${NC} Fila SQS já existe: ${YELLOW}$QUEUE_URL${NC}"
fi

ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)

QUEUE_ARN="arn:aws:sqs:$REGION:$ACCOUNT_ID:$QUEUE_NAME"
echo -e "${BLUE}[INFO]${NC} Queue ARN: ${YELLOW}$QUEUE_ARN${NC}"
echo ""

echo -e "${YELLOW}[STEP 3/9]${NC} Criando tabela DynamoDB..."

if aws dynamodb create-table \
  --table-name $TABLE_NAME \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Tabela DynamoDB criada"
else
  echo -e "${YELLOW}[AVISO]${NC} Tabela DynamoDB já existe"
fi
echo ""

echo -e "${YELLOW}[STEP 4/9]${NC} Criando IAM Role..."

cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
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
echo ""

echo -e "${YELLOW}[STEP 5/9]${NC} Criando policy customizada para SQS..."

cat > sqs-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "$QUEUE_ARN"
    }
  ]
}
EOF

POLICY_ARN=$(aws iam create-policy \
  --policy-name lambda-sqs-policy \
  --policy-document file://sqs-policy.json \
  --query 'Policy.Arn' \
  --output text 2>/dev/null || echo "")

if [ -z "$POLICY_ARN" ]; then
  POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/lambda-sqs-policy"
  echo -e "${YELLOW}[AVISO]${NC} Policy já existe"
else
  echo -e "${GREEN}[OK]${NC} Policy criada"
fi

echo -e "${BLUE}[INFO]${NC} Policy ARN: ${YELLOW}$POLICY_ARN${NC}"
echo ""

echo -e "${YELLOW}[STEP 6/9]${NC} Anexando policies na role..."

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess 2>/dev/null || true

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn $POLICY_ARN 2>/dev/null || true

echo -e "${GREEN}[OK]${NC} Policies anexadas"
echo ""

echo -e "${YELLOW}[STEP 7/9]${NC} Aguardando propagação IAM..."
sleep 15
echo -e "${GREEN}[OK]${NC} Propagação concluída"
echo ""

ROLE_ARN=$(aws iam get-role \
  --role-name $ROLE_NAME \
  --query 'Role.Arn' \
  --output text)

echo -e "${BLUE}[INFO]${NC} Role ARN: ${YELLOW}$ROLE_ARN${NC}"
echo ""

echo -e "${YELLOW}[STEP 8/9]${NC} Criando função Lambda..."

if aws lambda create-function \
  --function-name $LAMBDA_NAME \
  --runtime python3.12 \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://$ZIP_FILE \
  --role $ROLE_ARN \
  --timeout 30 \
  --memory-size 256 \
  --environment "Variables={QUEUE_URL=https://sqs.${REGION}.amazonaws.com/${ACCOUNT_ID}/SqsLambdaDynamodbQueue,TABLE_NAME=SqsLambdaDynamodbTable}" \
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
echo ""

echo -e "${YELLOW}[STEP 9/9]${NC} Configurando trigger SQS -> Lambda..."

# Aguardar Lambda ficar ativa
echo -e "${BLUE}[INFO]${NC} Aguardando Lambda ficar ativa..."
sleep 5

if aws lambda create-event-source-mapping \
  --function-name $LAMBDA_NAME \
  --event-source-arn $QUEUE_ARN \
  --batch-size 10 \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Trigger SQS configurado"
else
  echo -e "${YELLOW}[AVISO]${NC} Trigger já existe"
fi
echo ""

echo -e "${CYAN}=======================================${NC}"
echo -e "${GREEN}   DEPLOY FINALIZADO COM SUCESSO! 🚀${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""
echo -e "${BLUE}[FILA SQS CRIADA]${NC}"
echo -e "${GREEN}$QUEUE_URL${NC}"
echo ""
echo -e "${BLUE}[TESTE - Enviar mensagem para fila]${NC}"
echo -e "${YELLOW}aws sqs send-message \\${NC}"
echo -e "${YELLOW}  --queue-url $QUEUE_URL \\${NC}"
echo -e "${YELLOW}  --message-body '{\"produto\":\"Notebook\",\"quantidade\":2,\"preco\":3500.00,\"cliente\":\"João Silva\"}'${NC}"
echo ""
echo -e "${BLUE}[CONSULTAR DYNAMODB]${NC}"
echo -e "${YELLOW}aws dynamodb scan --table-name $TABLE_NAME --region $REGION${NC}"
echo ""
