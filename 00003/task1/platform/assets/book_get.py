import json
import os
from datetime import datetime, timezone, timedelta
import boto3

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

def handler(event, context):
    booking_id = (event.get("queryStringParameters") or {}).get("booking_id")
    if not booking_id:
        return {"statusCode": 400, "headers": {"content-type": "application/json"}, "body": json.dumps({"message": "booking_id is required"})}
    items = table.query(IndexName="booking_id-index", KeyConditionExpression="booking_id = :id", ExpressionAttributeValues={":id": booking_id}).get("Items", [])
    if not items:
        return {"statusCode": 404, "headers": {"content-type": "application/json"}, "body": json.dumps({"message": "not found"})}
    item = items[0]
    value = item.get("created_at", "")
    try:
        value = datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone(timedelta(hours=9))).strftime("%Y-%m-%d %H:%M:%S KST")
    except (ValueError, AttributeError):
        pass
    ordered = {"client_id": item.get("client_id"), "username": item.get("username"), "email": item.get("email"), "concert_name": item.get("concert_name"), "created_at": value}
    return {"statusCode": 200, "headers": {"content-type": "application/json"}, "body": json.dumps(ordered, ensure_ascii=False)}
