import base64
import json
import os
import socket

import boto3
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider
from kafka import KafkaProducer

try:
    from kafka.net.sasl.oauth import AbstractTokenProvider
except ImportError:
    from kafka.sasl.oauth import AbstractTokenProvider


_table = None
_producer = None


class MSKTokenProvider(AbstractTokenProvider):
    def token(self):
        token, _ = MSKAuthTokenProvider.generate_auth_token(os.environ["AWS_REGION"])
        return token


def get_table():
    global _table
    if _table is None:
        _table = boto3.resource("dynamodb").Table(os.environ["DDB_TABLE"])
    return _table


def get_producer():
    global _producer
    if _producer is None:
        _producer = KafkaProducer(
            bootstrap_servers=os.environ["BOOTSTRAP_SERVER"],
            security_protocol="SASL_SSL",
            sasl_mechanism="OAUTHBEARER",
            sasl_oauth_token_provider=MSKTokenProvider(),
            client_id=socket.gethostname(),
            value_serializer=lambda value: json.dumps(value).encode("utf-8"),
        )
    return _producer


def threshold_reasons(temperature, humidity):
    reasons = []
    if temperature > 80:
        reasons.append(f"Temperature exceeded threshold: {temperature}C")
    if temperature < 10:
        reasons.append(f"Temperature below threshold: {temperature}C")
    if humidity > 90:
        reasons.append(f"Humidity exceeded threshold: {humidity}%")
    if humidity < 20:
        reasons.append(f"Humidity below threshold: {humidity}%")
    return reasons


def process_item(item, table, producer):
    temperature = float(item["temperature"])
    humidity = float(item["humidity"])
    reasons = threshold_reasons(temperature, humidity)

    item["status"] = "ALERT" if reasons else "NORMAL"
    if reasons:
        item["alert_reason"] = "; ".join(reasons)

    stored = dict(item)
    stored["temperature"] = str(item["temperature"])
    stored["humidity"] = str(item["humidity"])
    table.put_item(Item=stored)

    if reasons:
        producer.send(os.environ["ALERT_TOPIC"], value=item).get(timeout=10)

    return bool(reasons)


def handler(event, context):
    table = get_table()
    producer = get_producer()
    processed = 0
    alerts = 0

    for records in event.get("records", {}).values():
        for record in records:
            item = json.loads(base64.b64decode(record["value"]))
            alerts += process_item(item, table, producer)
            processed += 1

    if alerts:
        producer.flush(timeout=10)

    return {"processed": processed, "alerts": alerts}
