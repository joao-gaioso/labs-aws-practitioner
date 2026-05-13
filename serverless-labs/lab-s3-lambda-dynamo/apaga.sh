#!/bin/bash

set -e

############################################
# CONFIGURAÇÕES
############################################

REGION="us-east-1"

BUCKET_NAME="lab-csv-1778131617"

TABLE_NAME="Usuarios"

LAMBDA_NAME="lambda-processa-csv"

ROLE_NAME="lambda-s3-role"

############################################
# INÍCIO
############################################

echo "======================================="
echo "REMOVENDO LAB SERVERLESS AWS"
echo "======================================="

############################################
# REMOVER NOTIFICAÇÃO S3
############################################

echo "Removendo trigger do bucket S3..."

aws s3api put-bucket-notification-configuration \
  --bucket $BUCKET_NAME \
  --notification-configuration '{}'

############################################
# REMOVER PERMISSÃO LAMBDA
############################################

echo "Removendo permission da Lambda..."

aws lambda remove-permission \
  --function-name $LAMBDA_NAME \
  --statement-id s3invoke \
  --region $REGION || true

############################################
# DELETAR LAMBDA
############################################

echo "Deletando Lambda..."

aws lambda delete-function \
  --function-name $LAMBDA_NAME \
  --region $REGION || true

############################################
# ESVAZIAR BUCKET
############################################

echo "Esvaziando bucket S3..."

aws s3 rm s3://$BUCKET_NAME --recursive || true

############################################
# DELETAR BUCKET
############################################

echo "Deletando bucket S3..."

aws s3api delete-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION || true

############################################
# DELETAR TABELA DYNAMODB
############################################

echo "Deletando tabela DynamoDB..."

aws dynamodb delete-table \
  --table-name $TABLE_NAME \
  --region $REGION || true

############################################
# REMOVER POLICIES DA ROLE
############################################

echo "Removendo policies da role..."

aws iam detach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole || true

aws iam detach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess || true

aws iam detach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess || true

############################################
# DELETAR ROLE IAM
############################################

echo "Deletando IAM Role..."

aws iam delete-role \
  --role-name $ROLE_NAME || true

############################################
# REMOVER ARQUIVOS LOCAIS
############################################

echo "Removendo arquivos locais..."

rm -f trust-policy.json
rm -f notification.json
rm -f lambda.zip

############################################
# FINAL
############################################

echo "======================================="
echo "LAB REMOVIDO COM SUCESSO 🚀"
echo "======================================="