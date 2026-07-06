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

# Preencha com o nome do bucket gerado pelo deploy.sh
BUCKET_NAME=""

TOPIC_NAME="lab-pedidos-topic"
QUEUE_NAME="lab-pedidos-queue"
TABLE_NAME="lab-pedidos"
LAMBDA_NAME="lambda-processa-pedidos"
ROLE_NAME="LambdaPedidosRole"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   INICIANDO CLEANUP LAB S3-SNS-SQS-LAMBDA ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

if [ -z "$BUCKET_NAME" ]; then
  echo -e "${RED}[ERRO]${NC} Variável BUCKET_NAME não definida!"
  echo -e "${YELLOW}[DICA]${NC} Edite este arquivo e preencha BUCKET_NAME com o nome gerado pelo deploy.sh"
  exit 1
fi

echo -e "${RED}[AVISO]${NC} Este script irá deletar TODOS os recursos criados pelo deploy."
echo -e "${YELLOW}Pressione CTRL+C para cancelar ou ENTER para continuar...${NC}"
read

echo ""
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${BLUE}[INFO]${NC} Account ID: ${YELLOW}$ACCOUNT_ID${NC}"
echo ""

# ─── STEP 1: Remover trigger SQS -> Lambda ───────────────────────────────────
echo -e "${YELLOW}[STEP 1/8]${NC} Removendo trigger SQS -> Lambda..."

QUEUE_ARN="arn:aws:sqs:$REGION:$ACCOUNT_ID:$QUEUE_NAME"

MAPPING_UUID=$(aws lambda list-event-source-mappings \
  --function-name $LAMBDA_NAME \
  --region $REGION \
  --query "EventSourceMappings[?EventSourceArn=='$QUEUE_ARN'].UUID" \
  --output text 2>/dev/null || echo "")

if [ -n "$MAPPING_UUID" ]; then
  aws lambda delete-event-source-mapping \
    --uuid $MAPPING_UUID \
    --region $REGION > /dev/null
  echo -e "${GREEN}[OK]${NC} Trigger removido"
else
  echo -e "${YELLOW}[AVISO]${NC} Trigger não encontrado"
fi
echo ""

# ─── STEP 2: Deletar Lambda ──────────────────────────────────────────────────
echo -e "${YELLOW}[STEP 2/8]${NC} Deletando função Lambda..."

if aws lambda delete-function \
  --function-name $LAMBDA_NAME \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Lambda deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} Lambda não encontrada"
fi
echo ""

# ─── STEP 3: Remover notificação e esvaziar/deletar bucket S3 ────────────────
echo -e "${YELLOW}[STEP 3/8]${NC} Removendo notificação e deletando bucket S3..."

aws s3api put-bucket-notification-configuration \
  --bucket $BUCKET_NAME \
  --notification-configuration '{}' 2>/dev/null || true

aws s3 rm s3://$BUCKET_NAME --recursive 2>/dev/null || true

if aws s3api delete-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Bucket S3 deletado"
else
  echo -e "${YELLOW}[AVISO]${NC} Bucket não encontrado"
fi
echo ""

# ─── STEP 4: Cancelar inscrição SQS no SNS e deletar tópico SNS ──────────────
echo -e "${YELLOW}[STEP 4/8]${NC} Deletando tópico SNS e inscrições..."

TOPIC_ARN="arn:aws:sns:$REGION:$ACCOUNT_ID:$TOPIC_NAME"

# Listar e deletar todas as inscrições do tópico
SUBSCRIPTIONS=$(aws sns list-subscriptions-by-topic \
  --topic-arn $TOPIC_ARN \
  --region $REGION \
  --query 'Subscriptions[*].SubscriptionArn' \
  --output text 2>/dev/null || echo "")

for SUB_ARN in $SUBSCRIPTIONS; do
  if [ "$SUB_ARN" != "PendingConfirmation" ]; then
    aws sns unsubscribe --subscription-arn $SUB_ARN --region $REGION 2>/dev/null || true
    echo -e "${BLUE}[INFO]${NC} Inscrição removida: ${YELLOW}$SUB_ARN${NC}"
  fi
done

if aws sns delete-topic \
  --topic-arn $TOPIC_ARN \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Tópico SNS deletado"
else
  echo -e "${YELLOW}[AVISO]${NC} Tópico SNS não encontrado"
fi
echo ""

# ─── STEP 5: Deletar fila SQS ────────────────────────────────────────────────
echo -e "${YELLOW}[STEP 5/8]${NC} Deletando fila SQS..."

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

# ─── STEP 6: Deletar tabela DynamoDB ─────────────────────────────────────────
echo -e "${YELLOW}[STEP 6/8]${NC} Deletando tabela DynamoDB..."

if aws dynamodb delete-table \
  --table-name $TABLE_NAME \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Tabela DynamoDB deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} Tabela DynamoDB não encontrada"
fi
echo ""

# ─── STEP 7: Desanexar policies e deletar IAM Role ───────────────────────────
echo -e "${YELLOW}[STEP 7/8]${NC} Removendo IAM Role e policies..."

aws iam detach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

aws iam detach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess 2>/dev/null || true

aws iam detach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess 2>/dev/null || true

aws iam detach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonSQSFullAccess 2>/dev/null || true

if aws iam delete-role \
  --role-name $ROLE_NAME 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} IAM Role deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} IAM Role não encontrada"
fi
echo ""

# ─── STEP 8: Limpar arquivos locais ──────────────────────────────────────────
echo -e "${YELLOW}[STEP 8/8]${NC} Limpando arquivos locais..."

rm -f trust-policy.json sqs-policy.json s3-notification.json

echo -e "${GREEN}[OK]${NC} Arquivos locais removidos"
echo ""

echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}   CLEANUP FINALIZADO! ✨                  ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
