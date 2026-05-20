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
echo -e "${CYAN}   INICIANDO CLEANUP LAB STEP FUNCTIONS     ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

echo -e "${RED}[AVISO]${NC} Este script irá deletar todos os recursos criados pelo deploy."
echo -e "${YELLOW}Pressione CTRL+C para cancelar ou ENTER para continuar...${NC}"
read

echo ""
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${BLUE}[INFO]${NC} Account ID: ${YELLOW}$ACCOUNT_ID${NC}"
echo ""

# ─── STEP 1: Deletar State Machine ───────────────────────────────────────────
echo -e "${YELLOW}[STEP 1/5]${NC} Deletando State Machine..."

STATE_MACHINE_ARN=$(aws stepfunctions list-state-machines \
  --region $REGION \
  --query "stateMachines[?name=='$STATE_MACHINE_NAME'].stateMachineArn" \
  --output text 2>/dev/null || echo "")

if [ -n "$STATE_MACHINE_ARN" ]; then
  aws stepfunctions delete-state-machine \
    --state-machine-arn $STATE_MACHINE_ARN \
    --region $REGION
  echo -e "${GREEN}[OK]${NC} State Machine deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} State Machine não encontrada"
fi
echo ""

# ─── STEP 2: Deletar Lambdas ─────────────────────────────────────────────────
echo -e "${YELLOW}[STEP 2/5]${NC} Deletando funções Lambda..."

for LAMBDA in $LAMBDA_VALIDA $LAMBDA_ESTOQUE $LAMBDA_TOTAL; do
  if aws lambda delete-function \
    --function-name $LAMBDA \
    --region $REGION 2>/dev/null; then
    echo -e "${GREEN}[OK]${NC} Lambda deletada: ${YELLOW}$LAMBDA${NC}"
  else
    echo -e "${YELLOW}[AVISO]${NC} Lambda não encontrada: ${YELLOW}$LAMBDA${NC}"
  fi
done
echo ""

# ─── STEP 3: Remover IAM Role das Lambdas ────────────────────────────────────
echo -e "${YELLOW}[STEP 3/5]${NC} Removendo IAM Role das Lambdas..."

aws iam detach-role-policy \
  --role-name $ROLE_LAMBDA \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

if aws iam delete-role \
  --role-name $ROLE_LAMBDA 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} IAM Role Lambda deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} IAM Role Lambda não encontrada"
fi
echo ""

# ─── STEP 4: Remover IAM Role da Step Functions ──────────────────────────────
echo -e "${YELLOW}[STEP 4/5]${NC} Removendo IAM Role da Step Functions..."

aws iam detach-role-policy \
  --role-name $ROLE_SFN \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/StepFunctionsInvokeLambdaPolicy 2>/dev/null || true

if aws iam delete-role \
  --role-name $ROLE_SFN 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} IAM Role Step Functions deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} IAM Role Step Functions não encontrada"
fi

if aws iam delete-policy \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/StepFunctionsInvokeLambdaPolicy 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} Policy customizada deletada"
else
  echo -e "${YELLOW}[AVISO]${NC} Policy customizada não encontrada"
fi
echo ""

# ─── STEP 5: Limpar arquivos locais ──────────────────────────────────────────
echo -e "${YELLOW}[STEP 5/5]${NC} Limpando arquivos locais..."

rm -f trust-lambda.json trust-sfn.json sfn-policy.json

echo -e "${GREEN}[OK]${NC} Arquivos locais removidos"
echo ""

echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}   CLEANUP FINALIZADO! ✨                  ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
