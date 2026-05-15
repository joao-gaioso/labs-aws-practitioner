import boto3
from datetime import datetime
import decimal
import json
import logging
import os
import uuid

logger = logging.getLogger()
logger.setLevel(logging.INFO)

QUEUE_URL = os.environ["QUEUE_URL"]
TABLE_NAME = os.environ["TABLE_NAME"]

dynamodb = boto3.resource("dynamodb")
tabela = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):
    """
    Função Lambda para processar eventos.
    
    Args:
        event: Evento recebido (SQS, S3, API Gateway, etc.)
        context: Contexto de execução da Lambda
    
    Returns:
        dict: Resposta com statusCode e body
    """
    logger.info(f"Evento recebido: {event}")

    total_processado = 0
    erros = []

    # Processar mensagens SQS
    for record in event["Records"]:
        try:
            # Extrair corpo da mensagem SQS
            body = json.loads(record["body"])
            
            logger.info(f"Processando mensagem: {body}")

            # Cria item para DynamoDB
            item = {
                "id": str(uuid.uuid4()),
                "data_processamento": datetime.now().isoformat(),
                "message_id": record["messageId"],
                "status": "processado"
            }
            
            # Adicionar campos da mensagem
            item.update(body)

            # Salvar no DynamoDB
            tabela.put_item(Item=item)
            
            logger.info(f"Item salvo com sucesso: {item['id']}")
            total_processado += 1

        except Exception as e:
            logger.error(f"Erro ao processar mensagem: {str(e)}")
            erros.append({
                "messageId": record.get("messageId"),
                "erro": str(e)
            })

    logger.info(f"Processamento finalizado. Total: {total_processado}, Erros: {len(erros)}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "mensagem": f"{total_processado} eventos processados com sucesso",
            "total_processado": total_processado,
            "total_erros": len(erros),
            "erros": erros
        })
    }
