import base64, json, os
import boto3
ddb=boto3.resource("dynamodb").Table(os.environ["DDB_TABLE"])
def handler(event, context):
    count=0
    for records in event.get("records",{}).values():
        for record in records:
            item=json.loads(base64.b64decode(record["value"]))
            temp=float(item["temperature"]); humidity=float(item["humidity"]); reasons=[]
            if temp>80: reasons.append(f"Temperature exceeded threshold: {temp}°C")
            if temp<10: reasons.append(f"Temperature below threshold: {temp}°C")
            if humidity>90: reasons.append(f"Humidity exceeded threshold: {humidity}%")
            if humidity<20: reasons.append(f"Humidity below threshold: {humidity}%")
            item["temperature"]=str(item["temperature"]); item["humidity"]=str(item["humidity"]); item["status"]="ALERT" if reasons else "NORMAL"
            if reasons: item["alert_reason"]="; ".join(reasons)
            ddb.put_item(Item=item); count+=1
    return {"processed":count}
