import json,os,boto3
table=boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
def handler(event,context):
 q=event.get("queryStringParameters") or {}; booking_id=q.get("booking_id")
 if not booking_id: return {"statusCode":400,"headers":{"content-type":"application/json"},"body":json.dumps({"error":"booking_id is required"})}
 item=table.get_item(Key={"booking_id":booking_id}).get("Item")
 return {"statusCode":200 if item else 404,"headers":{"content-type":"application/json"},"body":json.dumps(item or {"error":"not found"})}
