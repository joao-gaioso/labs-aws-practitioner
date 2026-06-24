import json
import logging
import os
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """
    Lambda de exemplo — retorna uma saudação personalizada.

    Parâmetros aceitos no evento:
        nome (str): Nome para personalizar a mensagem. Opcional.

    Variáveis de ambiente:
        NOME_PADRAO  — nome usado quando o evento não traz um "nome". Default: "Mundo".
        APP_VERSION  — versão da aplicação exibida na resposta.

    Retorno:
        dict com statusCode, headers e body JSON.
    """
    logger.info(f"Evento recebido: {json.dumps(event)}")

    # Lê o nome do evento; se não vier, usa a variável de ambiente; se não, "Mundo"
    nome = event.get("nome", os.environ.get("NOME_PADRAO", "Mundo"))

    if not nome:
        logger.warning("Requisicao invalida: campo 'nome' veio vazio.")
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(
                {"erro": "O campo 'nome' nao pode ser vazio."},
                ensure_ascii=False,
            ),
        }

    resposta = {
        "mensagem": f"Olá, {nome}! Esta é minha primeira Lambda com Terraform.",
        "versao": os.environ.get("APP_VERSION", "1.0.0"),
        "ambiente": os.environ.get("AMBIENTE"),
        "request_id": context.aws_request_id,
        "timestamp": datetime.now().isoformat(),
        }

    logger.info(f"Resposta enviada: {json.dumps(resposta)}")

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(resposta, ensure_ascii=False),
    }
