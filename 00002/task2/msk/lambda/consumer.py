import base64
import json
import os

import boto3

table = boto3.resource("dynamodb").Table(os.environ["DDB_TABLE"])


def handler(event, context):
    count = 0
    for records in event.get("records", {}).values():
        for record in records:
            item = json.loads(base64.b64decode(record["value"]))
            temperature = float(item["temperature"])
            humidity = float(item["humidity"])
            reasons = []
            if temperature > 80:
                reasons.append(f"Temperature exceeded threshold: {temperature}C")
            if temperature < 10:
                reasons.append(f"Temperature below threshold: {temperature}C")
            if humidity > 90:
                reasons.append(f"Humidity exceeded threshold: {humidity}%")
            if humidity < 20:
                reasons.append(f"Humidity below threshold: {humidity}%")

            item["status"] = "ALERT" if reasons else "NORMAL"
            if reasons:
                item["alert_reason"] = "; ".join(reasons)

            stored = dict(item)
            stored["temperature"] = str(item["temperature"])
            stored["humidity"] = str(item["humidity"])
            table.put_item(Item=stored)
            count += 1
    return {"processed": count}
