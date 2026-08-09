from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP

def handler(event, context):
    order = dict(event.get("order", event))
    total = Decimal(str(order["quantity"])) * Decimal(str(order["unit_price"]))
    order["total_amount"] = float(total)
    order["total_usd"] = float((total / Decimal("1350")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))
    order["ordered_at"] = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    order["payment_status"] = "APPROVED"
    order["processed_at"] = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    return order
