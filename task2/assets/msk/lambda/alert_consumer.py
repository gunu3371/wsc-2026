import base64
import json
import os

import boto3


sns = boto3.client("sns")
s3 = boto3.client("s3")


def process_item(item):
    sns.publish(
        TopicArn=os.environ["SNS_TOPIC_ARN"],
        Message=json.dumps(item),
    )
    s3.put_object(
        Bucket=os.environ["S3_BUCKET"],
        Key=(
            f"alert/{item['sensorId']}/{item['timestamp'][:10]}/"
            f"{item['timestamp'].replace(':', '-')}.json"
        ),
        Body=json.dumps(item),
        ContentType="application/json",
    )


def handler(event, context):
    processed = 0
    for records in event.get("records", {}).values():
        for record in records:
            item = json.loads(base64.b64decode(record["value"]))
            process_item(item)
            processed += 1
    return {"processed": processed}
