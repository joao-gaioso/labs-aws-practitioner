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
BUCKET_NAME="lab-csv-$(date +%s)"
TABLE_NAME="Usuarios"
LAMBDA_NAME="lambda-processa-csv"
ROLE_NAME="lambda-s3-role"
ZIP_FILE="lambda.zip"

echo -e "${CYAN}=======================================${NC}"
echo -e "${CYAN}   INICIANDO DEPLOY LAB S3-LAMBDA-DYNAMO${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""

echo -e "${BLUE}[INFO]${NC} Região: ${YELLOW}$REGION${NC}"
echo -e "${BLUE}[INFO]${NC} Bucket: ${YELLOW}$BUCKET_NAME${NC}"
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

echo -e "${YELLOW}[STEP 2/9]${NC} Criando bucket S3..."

if aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Bucket S3 criado: ${YELLOW}$BUCKET_NAME${NC}"
else
  echo -e "${RED}[ERRO]${NC} Falha ao criar bucket S3"
  exit 1
fi
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

echo -e "${YELLOW}[STEP 5/9]${NC} Anexando policies na role..."

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess 2>/dev/null || true

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess 2>/dev/null || true

echo -e "${GREEN}[OK]${NC} Policies anexadas"
echo ""

echo -e "${YELLOW}[STEP 6/9]${NC} Aguardando propagação IAM..."
sleep 15
echo -e "${GREEN}[OK]${NC} Propagação concluída"
echo ""

ROLE_ARN=$(aws iam get-role \
  --role-name $ROLE_NAME \
  --query 'Role.Arn' \
  --output text)

echo -e "${BLUE}[INFO]${NC} Role ARN: ${YELLOW}$ROLE_ARN${NC}"
echo ""

echo -e "${YELLOW}[STEP 7/9]${NC} Criando função Lambda..."

if aws lambda create-function \
  --function-name $LAMBDA_NAME \
  --runtime python3.12 \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://$ZIP_FILE \
  --role $ROLE_ARN \
  --timeout 30 \
  --memory-size 256 \
  --environment "Variables={TABLE_NAME=$TABLE_NAME}" \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Lambda criada com sucesso"
else
  echo -e "${YELLOW}[AVISO]${NC} Lambda já existe"
fi
echo ""

echo -e "${YELLOW}[STEP 8/9]${NC} Configurando permissão S3 -> Lambda..."

ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)

echo -e "${BLUE}[INFO]${NC} Account ID: ${YELLOW}$ACCOUNT_ID${NC}"

if aws lambda add-permission \
  --function-name $LAMBDA_NAME \
  --principal s3.amazonaws.com \
  --statement-id s3invoke \
  --action "lambda:InvokeFunction" \
  --source-arn arn:aws:s3:::$BUCKET_NAME \
  --source-account $ACCOUNT_ID \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Permissão adicionada"
else
  echo -e "${YELLOW}[AVISO]${NC} Permissão já existe"
fi
echo ""

echo -e "${YELLOW}[STEP 9/9]${NC} Configurando trigger S3..."

cat > notification.json <<EOF
{
  "LambdaFunctionConfigurations": [
    {
      "LambdaFunctionArn": "arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$LAMBDA_NAME",
      "Events": ["s3:ObjectCreated:Put"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {
              "Name": "suffix",
              "Value": ".csv"
            }
          ]
        }
      }
    }
  ]
}
EOF

aws s3api put-bucket-notification-configuration \
  --bucket $BUCKET_NAME \
  --notification-configuration file://notification.json

echo -e "${GREEN}[OK]${NC} Trigger S3 configurado"
echo ""

echo -e "${CYAN}=======================================${NC}"
echo -e "${GREEN}   DEPLOY FINALIZADO COM SUCESSO! 🚀${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""
echo -e "${BLUE}[BUCKET CRIADO]${NC}"
echo -e "${GREEN}$BUCKET_NAME${NC}"
echo ""
echo -e "${BLUE}[TESTE]${NC}"
echo -e "${YELLOW}aws s3 cp usuarios.csv s3://$BUCKET_NAME/usuarios.csv${NC}"
echo ""
echo -e "${BLUE}[VERIFICAR LOGS]${NC}"
echo -e "${YELLOW}aws logs tail /aws/lambda/$LAMBDA_NAME --follow${NC}"
echo ""