import base64, json, os
from datetime import datetime, timezone
import boto3
s3=boto3.client("s3"); sns=boto3.client("sns")
def handler(event, context):
    count=0
    for records in event.get("records",{}).values():
        for record in records:
            item=json.loads(base64.b64decode(record["value"])); sensor=item["sensorId"]; stamp=item["timestamp"]; date=stamp[:10]
            sns.publish(TopicArn=os.environ["SNS_TOPIC_ARN"],Subject=f"Sensor alert: {sensor}",Message=json.dumps(item))
            key=f"alert/{sensor}/{date}/{stamp.replace(':','-')}.json"; s3.put_object(Bucket=os.environ["S3_BUCKET"],Key=key,Body=json.dumps(item).encode(),ContentType="application/json"); count+=1
    return {"processed":count}
