import base64,json,os,boto3
sns=boto3.client("sns");s3=boto3.client("s3")
def handler(event,context):
    count=0
    for records in event.get("records",{}).values():
        for record in records:
            item=json.loads(base64.b64decode(record["value"])); sns.publish(TopicArn=os.environ["SNS_TOPIC_ARN"],Message=json.dumps(item)); s3.put_object(Bucket=os.environ["S3_BUCKET"],Key=f"alert/{item['sensorId']}/{item['timestamp'][:10]}/{item['timestamp'].replace(':','-')}.json",Body=json.dumps(item));count+=1
    return {"processed":count}

