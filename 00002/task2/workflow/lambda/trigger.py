import json, os, urllib.parse
import boto3
sfn=boto3.client("stepfunctions")
def handler(event,context):
    for record in event.get("Records",[]):
        key=urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        sfn.start_execution(stateMachineArn=os.environ["STATE_MACHINE_ARN"],input=json.dumps({"key":key}))
    return {"statusCode":200}

