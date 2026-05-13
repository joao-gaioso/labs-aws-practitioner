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
TABLE_NAME="Usuarios"
LAMBDA_NAME="lambda-usuarios-api"
ROLE_NAME="lambda-api-dynamodb-role"
API_NAME="api-usuarios-serverless"
STAGE_NAME="dev"

echo -e "${CYAN}=======================================${NC}"
echo -e "${CYAN}   INICIANDO CLEANUP SERVERLESS${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""

echo -e "${RED}[AVISO]${NC} Este script irá deletar todos os recursos criados pelo deploy"
echo -e "${YELLOW}Pressione CTRL+C para cancelar ou ENTER para continuar...${NC}"
read

echo ""
echo -e "${BLUE}[INFO]${NC} Região: ${YELLOW}$REGION${NC}"
echo ""

# Buscar API Gateway ID
echo -e "${YELLOW}[STEP 1/5]${NC} Buscando e deletando API Gateway..."

API_ID=$(aws apigateway get-rest-apis \
  --region $REGION \
  --query "items[?name=='$API_NAME'].id" \
  --output text 2>/dev/null || echo "")

if [ -n "$API_ID" ]; then
  echo -e "${BLUE}[INFO]${NC} API Gateway encontrada: ${YELLOW}$API_ID${NC}"
  aws apigateway delete-rest-api \
    --rest-api-id $API_ID \
    --region $REGION
  echo -e "${GREEN}[OK]${NC} API Gateway deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} API Gateway não encontrada"
fi
echo ""

# Deletar Lambda
echo -e "${YELLOW}[STEP 2/5]${NC} Deletando função Lambda..."

if aws lambda delete-function \
  --function-name $LAMBDA_NAME \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Lambda deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} Lambda não encontrada"
fi
echo ""

# Deletar IAM Role
echo -e "${YELLOW}[STEP 3/5]${NC} Removendo policies e deletando IAM Role..."

echo -e "${BLUE}[INFO]${NC} Desanexando policies..."
aws iam detach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

aws iam detach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess 2>/dev/null || true

echo -e "${BLUE}[INFO]${NC} Deletando role..."
if aws iam delete-role \
  --role-name $ROLE_NAME 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} IAM Role deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} IAM Role não encontrada"
fi
echo ""

# Deletar DynamoDB
echo -e "${YELLOW}[STEP 4/5]${NC} Deletando tabela DynamoDB..."

if aws dynamodb delete-table \
  --table-name $TABLE_NAME \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Tabela DynamoDB deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} Tabela DynamoDB não encontrada"
fi
echo ""

# Limpar arquivos locais
echo -e "${YELLOW}[STEP 5/5]${NC} Limpando arquivos locais..."

if [ -f "trust-policy.json" ]; then
  rm trust-policy.json
  echo -e "${GREEN}[OK]${NC} trust-policy.json removido"
fi

echo ""
echo -e "${CYAN}=======================================${NC}"
echo -e "${GREEN}   CLEANUP FINALIZADO! ✨${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""
