#!/bin/bash

QUEUE_URL="https://sqs.us-east-1.amazonaws.com/619425981855/lab-ana"
TABLE_NAME="lab-ana"
REGION="us-east-1"

echo "🧪 Testando Lab SQS-Lambda-DynamoDB"
echo ""

echo "📨 Enviando mensagem 1..."
aws sqs send-message \
  --queue-url "$QUEUE_URL" \
  --message-body '{"produto":"Notebook","quantidade":2,"preco":3500,"cliente":"João Silva"}' \
  --region $REGION

echo "✅ Mensagem 1 enviada!"
echo ""

echo "📨 Enviando mensagem 2..."
aws sqs send-message \
  --queue-url "$QUEUE_URL" \
  --message-body '{"produto":"Mouse","quantidade":5,"preco":50,"cliente":"Maria Santos"}' \
  --region $REGION

echo "✅ Mensagem 2 enviada!"
echo ""

echo "⏳ Aguardando processamento (5 segundos)..."
sleep 5

echo ""
echo "🔍 Consultando DynamoDB..."
aws dynamodb scan --table-name $TABLE_NAME --region $REGION

echo ""
echo "🎉 Teste concluído!"