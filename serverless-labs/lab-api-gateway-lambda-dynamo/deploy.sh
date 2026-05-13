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
ZIP_FILE="lambda.zip"

echo -e "${CYAN}=======================================${NC}"
echo -e "${CYAN}   INICIANDO DEPLOY SERVERLESS${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""

echo -e "${BLUE}[INFO]${NC} Região: ${YELLOW}$REGION${NC}"
echo -e "${BLUE}[INFO]${NC} Tabela DynamoDB: ${YELLOW}$TABLE_NAME${NC}"
echo -e "${BLUE}[INFO]${NC} Lambda: ${YELLOW}$LAMBDA_NAME${NC}"
echo -e "${BLUE}[INFO]${NC} API Gateway: ${YELLOW}$API_NAME${NC}"
echo ""

echo -e "${YELLOW}[STEP 1/8]${NC} Verificando lambda.zip..."

if [ ! -f "$ZIP_FILE" ]; then
  echo -e "${RED}[ERRO]${NC} $ZIP_FILE não encontrado!"
  echo -e "${YELLOW}[DICA]${NC} Crie o arquivo com: Compress-Archive -Path lambda_function.py -DestinationPath lambda.zip -Force"
  exit 1
fi
echo -e "${GREEN}[OK]${NC} lambda.zip encontrado"
echo ""

echo -e "${YELLOW}[STEP 2/8]${NC} Criando tabela DynamoDB..."

if aws dynamodb create-table \
  --table-name $TABLE_NAME \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Tabela DynamoDB criada com sucesso"
else
  echo -e "${YELLOW}[AVISO]${NC} Tabela DynamoDB já existe ou erro ao criar"
fi
echo ""

echo -e "${YELLOW}[STEP 3/8]${NC} Criando IAM Role..."

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
  echo -e "${GREEN}[OK]${NC} IAM Role criada com sucesso"
else
  echo -e "${YELLOW}[AVISO]${NC} IAM Role já existe"
fi
echo ""

echo -e "${YELLOW}[STEP 4/8]${NC} Anexando policies na role..."

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess 2>/dev/null || true

echo -e "${GREEN}[OK]${NC} Policies anexadas"
echo ""

echo -e "${YELLOW}[STEP 5/8]${NC} Aguardando propagação IAM..."
sleep 15
echo -e "${GREEN}[OK]${NC} Propagação concluída"
echo ""

ROLE_ARN=$(aws iam get-role \
  --role-name $ROLE_NAME \
  --query 'Role.Arn' \
  --output text)

echo -e "${BLUE}[INFO]${NC} Role ARN: ${YELLOW}$ROLE_ARN${NC}"
echo ""

echo -e "${YELLOW}[STEP 6/8]${NC} Criando função Lambda..."

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

echo -e "${YELLOW}[STEP 7/8]${NC} Configurando API Gateway..."

echo -e "${BLUE}[INFO]${NC} Criando REST API..."
API_ID=$(aws apigateway create-rest-api \
  --name $API_NAME \
  --region $REGION \
  --query 'id' \
  --output text)
echo -e "${GREEN}[OK]${NC} API criada com ID: ${YELLOW}$API_ID${NC}"

echo -e "${BLUE}[INFO]${NC} Obtendo root resource..."
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id $API_ID \
  --region $REGION \
  --query 'items[?path==`/`].id' \
  --output text)
echo -e "${GREEN}[OK]${NC} Root ID: ${YELLOW}$ROOT_ID${NC}"

echo -e "${BLUE}[INFO]${NC} Criando resource /usuarios..."
RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part usuarios \
  --region $REGION \
  --query 'id' \
  --output text)
echo -e "${GREEN}[OK]${NC} Resource ID: ${YELLOW}$RESOURCE_ID${NC}"

echo -e "${BLUE}[INFO]${NC} Criando método POST..."
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method POST \
  --authorization-type NONE \
  --region $REGION > /dev/null
echo -e "${GREEN}[OK]${NC} Método POST criado"

echo -e "${BLUE}[INFO]${NC} Configurando integração Lambda Proxy..."
ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)

LAMBDA_URI="arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$LAMBDA_NAME/invocations"

aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri $LAMBDA_URI \
  --region $REGION > /dev/null
echo -e "${GREEN}[OK]${NC} Integração configurada"

echo -e "${BLUE}[INFO]${NC} Adicionando permissão para API Gateway invocar Lambda..."
if aws lambda add-permission \
  --function-name $LAMBDA_NAME \
  --statement-id apigateway-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*/POST/usuarios" \
  --region $REGION 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Permissão adicionada"
else
  echo -e "${YELLOW}[AVISO]${NC} Permissão já existe"
fi
echo ""

echo -e "${YELLOW}[STEP 8/8]${NC} Fazendo deploy da API..."

aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name $STAGE_NAME \
  --region $REGION > /dev/null

echo -e "${GREEN}[OK]${NC} Deploy realizado no stage: ${YELLOW}$STAGE_NAME${NC}"
echo ""

echo -e "${CYAN}=======================================${NC}"
echo -e "${GREEN}   DEPLOY FINALIZADO COM SUCESSO! 🚀${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""
echo -e "${BLUE}[ENDPOINT]${NC}"
echo -e "${GREEN}https://$API_ID.execute-api.$REGION.amazonaws.com/$STAGE_NAME/usuarios${NC}"
echo ""
echo -e "${BLUE}[TESTE]${NC}"
echo -e "${YELLOW}curl -X POST https://$API_ID.execute-api.$REGION.amazonaws.com/$STAGE_NAME/usuarios \\${NC}"
echo -e "${YELLOW}  -H \"Content-Type: application/json\" \\${NC}"
echo -e "${YELLOW}  -d '{\"usuarios\":[{\"nome\":\"Joao\",\"idade\":25,\"email\":\"joao@email.com\"}]}'${NC}"
echo ""