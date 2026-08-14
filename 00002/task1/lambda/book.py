import json, os, uuid
from datetime import datetime, timezone, timedelta
import boto3
table=boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
def response(code,body): return {"statusCode":code,"isBase64Encoded":False,"headers":{"Content-Type":"application/json; charset=utf-8"},"body":json.dumps(body,ensure_ascii=False)}
def handler(event, context):
    method=event.get("httpMethod","")
    if method=="POST":
        try: item=json.loads(event.get("body") or "{}")
        except ValueError: return response(400,{"message":"invalid json"})
        required=["client_id","username","email","concert_name"]
        if any(not item.get(x) for x in required): return response(400,{"message":"missing required field"})
        item["booking_id"]=uuid.uuid4().hex[:8].upper(); item["created_at"]=datetime.now(timezone(timedelta(hours=9))).isoformat(); table.put_item(Item=item); return response(200,{"booking_id":item["booking_id"]})
    concert=(event.get("queryStringParameters") or {}).get("concert_name")
    if not concert: return response(400,{"message":"concert_name is required"})
    items=table.scan(FilterExpression="concert_name = :c",ExpressionAttributeValues={":c":concert}).get("Items",[]); items.sort(key=lambda x:x.get("created_at",""),reverse=True); return response(200,items)
