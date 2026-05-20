import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """
    Valida se o pedido contém os campos obrigatórios e se os valores são válidos.

    Recebe:
        event: {
            "cliente": "Ana Lima",
            "produto": "Notebook",
            "quantidade": 2,
            "preco_unitario": 4500.00
        }

    Retorna:
        dict com os dados originais + campo "valido" (bool) e "motivo" (str)
    """
    logger.info(f"Validando pedido: {json.dumps(event)}")

    campos_obrigatorios = ["cliente", "produto", "quantidade", "preco_unitario"]
    for campo in campos_obrigatorios:
        if campo not in event or event[campo] is None:
            logger.warning(f"Campo obrigatório ausente: {campo}")
            return {**event, "valido": False, "motivo": f"Campo obrigatório ausente: {campo}"}

    if event["quantidade"] <= 0:
        return {**event, "valido": False, "motivo": "Quantidade deve ser maior que zero"}

    if event["preco_unitario"] <= 0:
        return {**event, "valido": False, "motivo": "Preço unitário deve ser maior que zero"}

    logger.info("Pedido válido")
    return {**event, "valido": True, "motivo": "Pedido válido"}
