import boto3
import csv
import uuid
import os
import urllib.parse
import logging

from io import StringIO

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TABLE_NAME = os.environ["TABLE_NAME"]

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
tabela = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):

    logger.info(f"Evento recebido: {event}")

    record = event["Records"][0]

    bucket = record["s3"]["bucket"]["name"]

    key = urllib.parse.unquote_plus(
        record["s3"]["object"]["key"]
    )

    logger.info(f"Bucket recebido: {bucket}")
    logger.info(f"Arquivo recebido: {key}")

    response = s3.get_object(
        Bucket=bucket,
        Key=key
    )

    conteudo = response["Body"].read().decode("utf-8")

    csv_file = StringIO(conteudo)

    leitor = csv.DictReader(csv_file)

    total = 0

    with tabela.batch_writer() as batch:

        for linha in leitor:

            item = {
                "id": str(uuid.uuid4()),
                "nome": linha.get("nome"),
                "idade": linha.get("idade"),
                "email": linha.get("email"),
                "arquivo_origem": key
            }

            logger.info(f"Salvando usuário: {item}")

            batch.put_item(Item=item)

            total += 1

    logger.info(f"Processamento finalizado. Total: {total}")

    return {
        "statusCode": 200,
        "body": f"{total} usuários importados com sucesso do arquivo {key}"
    }