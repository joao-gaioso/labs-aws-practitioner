import json
import logging
import random

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Estoque exemplo
ESTOQUE = {
    "Notebook":      10,
    "Mouse":         50,
    "Teclado":       30,
    "Monitor":        5,
    "Headset":       20,
    "Webcam":        15,
}

ESTOQUE_PADRAO = 8


def lambda_handler(event, context):
    """
    Verifica se há estoque suficiente para o pedido.

    Recebe:
        event: dados do pedido com campo "valido": True

    Retorna:
        dict com os dados originais + "estoque_disponivel" (int) e "tem_estoque" (bool)
    """
    logger.info(f"Verificando estoque: {json.dumps(event)}")

    produto = event.get("produto", "")
    quantidade = event.get("quantidade", 0)

    estoque_disponivel = ESTOQUE.get(produto, ESTOQUE_PADRAO)

    tem_estoque = estoque_disponivel >= quantidade

    logger.info(
        f"Produto: {produto} | "
        f"Solicitado: {quantidade} | "
        f"Disponível: {estoque_disponivel} | "
        f"Tem estoque: {tem_estoque}"
    )

    return {
        **event,
        "estoque_disponivel": estoque_disponivel,
        "tem_estoque": tem_estoque,
    }
