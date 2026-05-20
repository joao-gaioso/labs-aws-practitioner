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
LAMBDA_VALIDA="lambda-valida-pedido"
LAMBDA_ESTOQUE="lambda-verifica-estoque"
LAMBDA_TOTAL="lambda-calcula-total"
ROLE_LAMBDA="StepFunctionsLambdaRole"
ROLE_SFN="StepFunctionsExecRole"
STATE_MACHINE_NAME="fluxo-aprovacao-pedido"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   INICIANDO DEPLOY LAB STEP FUNCTIONS      ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${BLUE}[INFO]${NC} Região:          ${YELLOW}$REGION${NC}"
echo -e "${BLUE}[INFO]${NC} Lambda Valida:   ${YELLOW}$LAMBDA_VALIDA${NC}"
echo -e "${BLUE}[INFO]${NC} Lambda Estoque:  ${YELLOW}$LAMBDA_ESTOQUE${NC}"
echo -e "${BLUE}[INFO]${NC} Lambda Total:    ${YELLOW}$LAMBDA_TOTAL${NC}"
echo -e "${BLUE}[INFO]${NC} State Machine:   ${YELLOW}$STATE_MACHINE_NAME${NC}"
echo ""

# ─── STEP 1: Verificar zips ──────────────────────────────────────────────────
echo -e "${YELLOW}[STEP 1/7]${NC} Verificando arquivos .zip das Lambdas..."

for ZIP in valida.zip estoque.zip total.zip; do
  if [ ! -f "$ZIP" ]; then
    echo -e "${RED}[ERRO]${NC} $ZIP não encontrado!"
    echo ""
    echo -e "${YELLOW}[DICA]${NC} Gere os zips com os comandos abaixo:"
    echo ""
    echo -e "${YELLOW}  Windows (PowerShell):${NC}"
    echo -e "  Compress-Archive -Path lambda_valida_pedido.py   -DestinationPath valida.zip   -Force"
    echo -e "  Compress-Archive -Path lambda_verifica_estoque.py -DestinationPath estoque.zip -Force"
    echo -e "  Compress-Archive -Path lambda_calcula_total.py   -DestinationPath total.zip    -Force"
    echo ""
    echo -e "${YELLOW}  Linux/Mac:${NC}"
    echo -e "  zip valida.zip   lambda_valida_pedido.py"
    echo -e "  zip estoque.zip  lambda_verifica_estoque.py"
    echo -e "  zip total.zip    lambda_calcula_total.py"
    exit 1
  fi
done
echo -e "${GREEN}[OK]${NC} Todos os zips encontrados"
echo ""

# ─── STEP 2: Account ID ──────────────────────────────────────────────────────
echo -e "${YELLOW}[STEP 2/7]${NC} Obtendo Account ID..."

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}[OK]${NC} Account ID: ${YELLOW}$ACCOUNT_ID${NC}"
echo ""

# ─── STEP 3: IAM Role para as Lambdas ────────────────────────────────────────
echo -e "${YELLOW}[STEP 3/7]${NC} Criando IAM Role para as Lambdas..."

cat > trust-lambda.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

if aws iam create-role \
  --role-name $ROLE_LAMBDA \
  --assume-role-policy-document file://trust-lambda.json 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} IAM Role Lambda criada"
else
  echo -e "${YELLOW}[AVISO]${NC} IAM Role Lambda já existe"
fi

aws iam attach-role-policy \
  --role-name $ROLE_LAMBDA \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

echo -e "${BLUE}[INFO]${NC} Aguardando propagação IAM (15s)..."
sleep 15

ROLE_LAMBDA_ARN=$(aws iam get-role \
  --role-name $ROLE_LAMBDA \
  --query 'Role.Arn' \
  --output text)

echo -e "${GREEN}[OK]${NC} Role ARN: ${YELLOW}$ROLE_LAMBDA_ARN${NC}"
echo ""

# ─── STEP 4: Criar as três Lambdas ───────────────────────────────────────────
echo -e "${YELLOW}[STEP 4/7]${NC} Criando funções Lambda..."

create_or_update_lambda() {
  local NAME=$1
  local ZIP=$2
  local HANDLER=$3

  if aws lambda create-function \
    --function-name $NAME \
    --runtime python3.12 \
    --handler $HANDLER \
    --zip-file fileb://$ZIP \
    --role $ROLE_LAMBDA_ARN \
    --timeout 30 \
    --memory-size 128 \
    --region $REGION 2>/dev/null; then
    echo -e "${GREEN}[OK]${NC} Lambda criada: ${YELLOW}$NAME${NC}"
  else
    echo -e "${YELLOW}[AVISO]${NC} Lambda já existe, atualizando código: ${YELLOW}$NAME${NC}"
    aws lambda update-function-code \
      --function-name $NAME \
      --zip-file fileb://$ZIP \
      --region $REGION > /dev/null
    echo -e "${GREEN}[OK]${NC} Lambda atualizada: ${YELLOW}$NAME${NC}"
  fi
}

create_or_update_lambda "$LAMBDA_VALIDA"  "valida.zip"  "lambda_valida_pedido.lambda_handler"
create_or_update_lambda "$LAMBDA_ESTOQUE" "estoque.zip" "lambda_verifica_estoque.lambda_handler"
create_or_update_lambda "$LAMBDA_TOTAL"   "total.zip"   "lambda_calcula_total.lambda_handler"

echo ""

# ─── STEP 5: Obter ARNs das Lambdas ──────────────────────────────────────────
echo -e "${YELLOW}[STEP 5/7]${NC} Obtendo ARNs das Lambdas..."

LAMBDA_VALIDA_ARN=$(aws lambda get-function \
  --function-name $LAMBDA_VALIDA \
  --region $REGION \
  --query 'Configuration.FunctionArn' \
  --output text)

LAMBDA_ESTOQUE_ARN=$(aws lambda get-function \
  --function-name $LAMBDA_ESTOQUE \
  --region $REGION \
  --query 'Configuration.FunctionArn' \
  --output text)

LAMBDA_TOTAL_ARN=$(aws lambda get-function \
  --function-name $LAMBDA_TOTAL \
  --region $REGION \
  --query 'Configuration.FunctionArn' \
  --output text)

echo -e "${GREEN}[OK]${NC} ARN Valida:  ${YELLOW}$LAMBDA_VALIDA_ARN${NC}"
echo -e "${GREEN}[OK]${NC} ARN Estoque: ${YELLOW}$LAMBDA_ESTOQUE_ARN${NC}"
echo -e "${GREEN}[OK]${NC} ARN Total:   ${YELLOW}$LAMBDA_TOTAL_ARN${NC}"
echo ""

# ─── STEP 6: IAM Role para a Step Functions ──────────────────────────────────
echo -e "${YELLOW}[STEP 6/7]${NC} Criando IAM Role para Step Functions..."

cat > trust-sfn.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "states.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

if aws iam create-role \
  --role-name $ROLE_SFN \
  --assume-role-policy-document file://trust-sfn.json 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} IAM Role Step Functions criada"
else
  echo -e "${YELLOW}[AVISO]${NC} IAM Role Step Functions já existe"
fi

# Policy para invocar as três Lambdas
cat > sfn-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "lambda:InvokeFunction",
    "Resource": [
      "$LAMBDA_VALIDA_ARN",
      "$LAMBDA_ESTOQUE_ARN",
      "$LAMBDA_TOTAL_ARN"
    ]
  }]
}
EOF

POLICY_ARN=$(aws iam create-policy \
  --policy-name StepFunctionsInvokeLambdaPolicy \
  --policy-document file://sfn-policy.json \
  --query 'Policy.Arn' \
  --output text 2>/dev/null || \
  echo "arn:aws:iam::$ACCOUNT_ID:policy/StepFunctionsInvokeLambdaPolicy")

aws iam attach-role-policy \
  --role-name $ROLE_SFN \
  --policy-arn $POLICY_ARN 2>/dev/null || true

echo -e "${BLUE}[INFO]${NC} Aguardando propagação IAM (10s)..."
sleep 10

ROLE_SFN_ARN=$(aws iam get-role \
  --role-name $ROLE_SFN \
  --query 'Role.Arn' \
  --output text)

echo -e "${GREEN}[OK]${NC} Role SFN ARN: ${YELLOW}$ROLE_SFN_ARN${NC}"
echo ""

# ─── STEP 7: Criar a State Machine ───────────────────────────────────────────
echo -e "${YELLOW}[STEP 7/7]${NC} Criando State Machine..."

# Substituir os placeholders de ARN no arquivo da state machine
DEFINITION=$(cat state_machine.json \
  | sed "s|\${LAMBDA_VALIDA_ARN}|$LAMBDA_VALIDA_ARN|g" \
  | sed "s|\${LAMBDA_ESTOQUE_ARN}|$LAMBDA_ESTOQUE_ARN|g" \
  | sed "s|\${LAMBDA_TOTAL_ARN}|$LAMBDA_TOTAL_ARN|g")

# Verificar se a state machine já existe
EXISTING_ARN=$(aws stepfunctions list-state-machines \
  --region $REGION \
  --query "stateMachines[?name=='$STATE_MACHINE_NAME'].stateMachineArn" \
  --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_ARN" ]; then
  echo -e "${YELLOW}[AVISO]${NC} State Machine já existe, atualizando..."
  aws stepfunctions update-state-machine \
    --state-machine-arn $EXISTING_ARN \
    --definition "$DEFINITION" \
    --role-arn $ROLE_SFN_ARN \
    --region $REGION > /dev/null
  STATE_MACHINE_ARN=$EXISTING_ARN
  echo -e "${GREEN}[OK]${NC} State Machine atualizada"
else
  STATE_MACHINE_ARN=$(aws stepfunctions create-state-machine \
    --name $STATE_MACHINE_NAME \
    --definition "$DEFINITION" \
    --role-arn $ROLE_SFN_ARN \
    --type EXPRESS \
    --region $REGION \
    --query 'stateMachineArn' \
    --output text)
  echo -e "${GREEN}[OK]${NC} State Machine criada"
fi

echo -e "${BLUE}[INFO]${NC} ARN: ${YELLOW}$STATE_MACHINE_ARN${NC}"
echo ""

# ─── Resumo ───────────────────────────────────────────────────────────────────
echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}   DEPLOY FINALIZADO COM SUCESSO! 🚀       ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${BLUE}[STATE MACHINE ARN]${NC}"
echo -e "  ${YELLOW}$STATE_MACHINE_ARN${NC}"
echo ""
echo -e "${BLUE}[TESTE - Pedido válido com desconto]${NC}"
echo -e "${YELLOW}  aws stepfunctions start-execution \\${NC}"
echo -e "${YELLOW}    --state-machine-arn $STATE_MACHINE_ARN \\${NC}"
echo -e "${YELLOW}    --input '{\"cliente\":\"Ana Lima\",\"produto\":\"Notebook\",\"quantidade\":5,\"preco_unitario\":4500.00}' \\${NC}"
echo -e "${YELLOW}    --region $REGION${NC}"
echo ""
echo -e "${BLUE}[TESTE - Pedido inválido (sem campo)]${NC}"
echo -e "${YELLOW}  aws stepfunctions start-execution \\${NC}"
echo -e "${YELLOW}    --state-machine-arn $STATE_MACHINE_ARN \\${NC}"
echo -e "${YELLOW}    --input '{\"cliente\":\"Carlos\",\"produto\":\"Mouse\"}' \\${NC}"
echo -e "${YELLOW}    --region $REGION${NC}"
echo ""
echo -e "${BLUE}[VISUALIZAR NO CONSOLE]${NC}"
echo -e "  https://console.aws.amazon.com/states/home?region=$REGION#/statemachines"
echo ""
