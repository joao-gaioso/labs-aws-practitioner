import boto3
import uuid
import os
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TABLE_NAME = os.environ["TABLE_NAME"]

dynamodb = boto3.resource("dynamodb")
tabela = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    logger.info(f"Evento recebido: {event}")

    body = json.loads(event.get("body", "{}"))
    usuarios = body.get("usuarios", [])

    if not usuarios:
        return {
            "statusCode": 400,
            "headers": {
                "Content-Type": "application/json"
            },
            "body": json.dumps({
                "erro": "Nenhum usuário enviado"
            })
        }

    with tabela.batch_writer() as batch:
        for usuario in usuarios:
            item = {
                "id": str(uuid.uuid4()),
                "nome": usuario.get("nome"),
                "idade": usuario.get("idade"),
                "email": usuario.get("email")
            }

            logger.info(f"Salvando usuário: {item}")
            batch.put_item(Item=item)

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps({
            "mensagem": f"{len(usuarios)} usuários salvos com sucesso"
        })
    }