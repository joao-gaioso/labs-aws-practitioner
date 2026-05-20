import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Regras de desconto por quantidade
# Comprou 5 ou mais  → 10% de desconto
# Comprou 10 ou mais → 20% de desconto
REGRAS_DESCONTO = [
    {"quantidade_minima": 10, "percentual": 20},
    {"quantidade_minima": 5,  "percentual": 10},
]


def lambda_handler(event, context):
    """
    Calcula o valor total do pedido aplicando desconto por quantidade.

    Recebe:
        event: dados do pedido com "quantidade" e "preco_unitario"

    Retorna:
        dict com os dados originais + "percentual_desconto", "valor_desconto" e "total"
    """
    logger.info(f"Calculando total: {json.dumps(event)}")

    quantidade = event["quantidade"]
    preco_unitario = event["preco_unitario"]

    subtotal = quantidade * preco_unitario

    # Determinar percentual de desconto
    percentual_desconto = 0
    for regra in REGRAS_DESCONTO:
        if quantidade >= regra["quantidade_minima"]:
            percentual_desconto = regra["percentual"]
            break

    valor_desconto = round(subtotal * (percentual_desconto / 100), 2)
    total = round(subtotal - valor_desconto, 2)

    logger.info(
        f"Subtotal: R${subtotal:.2f} | "
        f"Desconto: {percentual_desconto}% (R${valor_desconto:.2f}) | "
        f"Total: R${total:.2f}"
    )

    return {
        **event,
        "subtotal": subtotal,
        "percentual_desconto": percentual_desconto,
        "valor_desconto": valor_desconto,
        "total": total,
    }
