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
QUEUE_NAME=""
TABLE_NAME=""
LAMBDA_NAME=""
ROLE_NAME="SqsLambdaDynamodbLambdaRole"

echo -e "${CYAN}=======================================${NC}"
echo -e "${CYAN}   INICIANDO CLEANUP LAB SQS LAMBDA DYNAMODB${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""

echo -e "${RED}[AVISO]${NC} Este script irá deletar todos os recursos criados pelo deploy"
echo -e "${YELLOW}Pressione CTRL+C para cancelar ou ENTER para continuar...${NC}"
read

echo ""
echo -e "${BLUE}[INFO]${NC} Região: ${YELLOW}$REGION${NC}"
echo ""

ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)

echo -e "${BLUE}[INFO]${NC} Account ID: ${YELLOW}$ACCOUNT_ID${NC}"
echo ""

# Remover Event Source Mapping
echo -e "${YELLOW}[STEP 1/6]${NC} Removendo trigger SQS -> Lambda..."

MAPPING_UUID=$(aws lambda list-event-source-mappings \
  --function-name $LAMBDA_NAME \
  --region $REGION \
  --query "EventSourceMappings[?contains(EventSourceArn, '$QUEUE_NAME')].UUID" \
  --output text 2>/dev/null || echo "")

if [ -n "$MAPPING_UUID" ]; then
  echo -e "${BLUE}[INFO]${NC} Mapping UUID: ${YELLOW}$MAPPING_UUID${NC}"
  aws lambda delete-event-source-mapping \
    --uuid $MAPPING_UUID \
    --region $REGION
  echo -e "${GREEN}[OK]${NC} Trigger removido"
else
  echo -e "${YELLOW}[AVISO]${NC} Trigger não encontrado"
fi
echo ""

# Deletar Lambda
echo -e "${YELLOW}[STEP 2/6]${NC} Deletando função Lambda..."

if aws lambda delete-function \
  --function-name $LAMBDA_NAME \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Lambda deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} Lambda não encontrada"
fi
echo ""

# Deletar Fila SQS
echo -e "${YELLOW}[STEP 3/6]${NC} Deletando fila SQS..."

QUEUE_URL=$(aws sqs get-queue-url \
  --queue-name $QUEUE_NAME \
  --region $REGION \
  --query 'QueueUrl' \
  --output text 2>/dev/null || echo "")

if [ -n "$QUEUE_URL" ]; then
  aws sqs delete-queue \
    --queue-url $QUEUE_URL \
    --region $REGION
  echo -e "${GREEN}[OK]${NC} Fila SQS deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} Fila SQS não encontrada"
fi
echo ""

# Deletar IAM Role
echo -e "${YELLOW}[STEP 4/6]${NC} Removendo policies e deletando IAM Role..."

echo -e "${BLUE}[INFO]${NC} Desanexando policies..."
aws iam detach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

aws iam detach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess 2>/dev/null || true

aws iam detach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/lambda-sqs-policy 2>/dev/null || true

echo -e "${BLUE}[INFO]${NC} Deletando role..."
if aws iam delete-role \
  --role-name $ROLE_NAME 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} IAM Role deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} IAM Role não encontrada"
fi
echo ""

# Deletar Policy customizada
echo -e "${YELLOW}[STEP 5/6]${NC} Deletando policy customizada..."

if aws iam delete-policy \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/lambda-sqs-policy 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Policy deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} Policy não encontrada"
fi
echo ""

# Deletar DynamoDB
echo -e "${YELLOW}[STEP 6/6]${NC} Deletando tabela DynamoDB..."

if aws dynamodb delete-table \
  --table-name $TABLE_NAME \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Tabela DynamoDB deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} Tabela DynamoDB não encontrada"
fi
echo ""

# Limpar arquivos locais
echo -e "${BLUE}[INFO]${NC} Limpando arquivos locais..."

rm -f trust-policy.json
rm -f sqs-policy.json

echo -e "${GREEN}[OK]${NC} Arquivos locais removidos"
echo ""

echo -e "${CYAN}=======================================${NC}"
echo -e "${GREEN}   CLEANUP FINALIZADO! ✨${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""
