def handler(event, context):
    order = event.get("order", event)
    errors = []
    if not str(order.get("order_id", "")).startswith("ORD-"): errors.append("order_id must start with ORD-")
    if not str(order.get("product_id", "")).strip(): errors.append("product_id is required")
    if float(order.get("quantity", 0)) < 1: errors.append("quantity must be at least 1")
    if float(order.get("unit_price", 0)) <= 0: errors.append("unit_price must be greater than 0")
    if order.get("payment_method") not in ("CARD", "BANK_TRANSFER"): errors.append("invalid payment_method")
    return {"valid": not errors, "order": order, "errors": errors}
