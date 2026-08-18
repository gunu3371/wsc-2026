import os,boto3
table=boto3.resource('dynamodb').Table(os.environ['TABLE_NAME'])
def handler(event,context):
 q=event.get('queryStringParameters') or {}; bid=q.get('booking_id')
 if not bid:return {'statusCode':400,'headers':{'content-type':'application/json'},'body':'{"error":"booking_id required"}'}
 item=table.get_item(Key={'booking_id':bid}).get('Item')
 return {'statusCode':200 if item else 404,'headers':{'content-type':'application/json'},'body':__import__('json').dumps(item or {'error':'not found'})}
