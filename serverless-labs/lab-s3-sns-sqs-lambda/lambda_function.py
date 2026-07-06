import boto3
import json
import logging
import os
import uuid
from datetime import datetime
from decimal import Decimal
from io import StringIO

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TABLE_NAME = os.environ["TABLE_NAME"]

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
tabela = dynamodb.Table(TABLE_NAME)


def floats_to_decimal(obj):
    """Converte recursivamente floats para Decimal (exigido pelo DynamoDB)."""
    if isinstance(obj, float):
        return Decimal(str(obj))
    if isinstance(obj, dict):
        return {k: floats_to_decimal(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [floats_to_decimal(i) for i in obj]
    return obj


def lambda_handler(event, context):
    """
    Função Lambda para processar pedidos em batch.

    Fluxo:
      1. Um arquivo JSON é enviado para o bucket S3
      2. O S3 publica uma notificação no tópico SNS
      3. O SNS entrega a mensagem na fila SQS
      4. O SQS dispara esta Lambda com até 10 mensagens por vez
      5. A Lambda lê o arquivo JSON do S3 e salva cada pedido no DynamoDB

    Args:
        event: Evento SQS contendo registros com notificações do S3 via SNS
        context: Contexto de execução da Lambda
    """
    logger.info(f"Evento recebido: {json.dumps(event)}")

    total_processado = 0
    total_erros = 0

    # Cada record é uma mensagem SQS
    for sqs_record in event["Records"]:

        try:
            # O corpo da mensagem SQS é uma notificação SNS
            sns_message = json.loads(sqs_record["body"])

            # O campo Message do SNS contém a notificação original do S3
            s3_notification = json.loads(sns_message["Message"])

            logger.info(f"Notificação S3 recebida: {json.dumps(s3_notification)}")

            # Processar cada arquivo da notificação S3
            for s3_record in s3_notification["Records"]:

                bucket = s3_record["s3"]["bucket"]["name"]
                key = s3_record["s3"]["object"]["key"]

                logger.info(f"Processando arquivo: s3://{bucket}/{key}")

                # Baixar o arquivo JSON do S3
                response = s3.get_object(Bucket=bucket, Key=key)
                conteudo = response["Body"].read().decode("utf-8")
                pedidos = json.loads(conteudo)

                # Garantir que é uma lista
                if isinstance(pedidos, dict):
                    pedidos = [pedidos]

                logger.info(f"Total de pedidos no arquivo: {len(pedidos)}")

                # Salvar cada pedido no DynamoDB usando batch_writer
                with tabela.batch_writer() as batch:
                    for pedido in pedidos:

                        item = {
                            "id": str(uuid.uuid4()),
                            "data_processamento": datetime.now().isoformat(),
                            "arquivo_origem": key,
                            "status": "processado",
                        }

                        # Adicionar todos os campos do pedido
                        item.update(pedido)

                        # Converter floats para Decimal (requisito do DynamoDB)
                        item = floats_to_decimal(item)

                        logger.info(f"Salvando pedido: {item['id']} - cliente: {item.get('cliente', 'N/A')}")

                        batch.put_item(Item=item)
                        total_processado += 1

                logger.info(f"Arquivo {key} processado com sucesso. Pedidos salvos: {len(pedidos)}")

        except Exception as e:
            logger.error(f"Erro ao processar mensagem SQS: {str(e)}")
            total_erros += 1
            raise  # relança para o SQS fazer retry → DLQ após maxReceiveCount

    logger.info(
        f"Processamento finalizado. "
        f"Total processado: {total_processado}, "
        f"Total erros: {total_erros}"
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "mensagem": f"{total_processado} pedidos processados com sucesso",
            "total_processado": total_processado,
            "total_erros": total_erros,
        }),
    }
