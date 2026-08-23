import base64
import importlib.util
import json
import os
from pathlib import Path
import sys
import types
import unittest


TASK_ROOT = Path(__file__).resolve().parents[1]


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FakeBody:
    def __init__(self, data):
        self.data = data

    def read(self):
        return self.data


class FakeS3:
    def __init__(self, csv_bytes=b""):
        self.csv_bytes = csv_bytes
        self.objects = []

    def get_object(self, **kwargs):
        return {"Body": FakeBody(self.csv_bytes)}

    def put_object(self, **kwargs):
        self.objects.append(kwargs)


class FakeTable:
    def __init__(self):
        self.items = []

    def put_item(self, **kwargs):
        self.items.append(kwargs["Item"])


class FakeDynamoResource:
    def __init__(self, table):
        self.table = table

    def Table(self, name):
        return self.table


class FakeFuture:
    def get(self, timeout):
        return None


class FakeProducer:
    def __init__(self):
        self.messages = []
        self.flush_count = 0

    def send(self, topic, value):
        self.messages.append((topic, value))
        return FakeFuture()

    def flush(self, timeout):
        self.flush_count += 1


class WorkflowTests(unittest.TestCase):
    def test_official_csv_processing_and_workflow_move(self):
        fake_boto3 = types.ModuleType("boto3")
        fake_boto3.client = lambda service: None
        fake_boto3.resource = lambda service: None
        sys.modules["boto3"] = fake_boto3

        processor = load_module(
            "workflow_processor",
            TASK_ROOT / "assets/workflow/lambda/processor.py",
        )
        csv_bytes = (TASK_ROOT / "assets/workflow/test.csv").read_bytes()
        fake_s3 = FakeS3(csv_bytes)
        fake_table = FakeTable()
        processor.s3 = fake_s3
        processor.ddb = FakeDynamoResource(fake_table)
        os.environ["S3_BUCKET"] = "test-bucket"
        os.environ["DDB_TABLE"] = "wsc2026-student-score"

        result = processor.handler({"key": "input/test.csv"}, None)

        self.assertEqual(497, len(csv_bytes))
        self.assertEqual(5, result["processed"])
        self.assertEqual(4, result["errors"])
        self.assertEqual(4, len(fake_s3.objects))
        student = next(item for item in fake_table.items if item["studentId"] == "STU1020")
        self.assertEqual("96.6", str(student["average"]))
        self.assertEqual("A", student["grade"])

        definition = (TASK_ROOT / "workflow/03-step-functions.tf").read_text(encoding="utf-8")
        self.assertIn("processed/{}", definition)
        self.assertIn("deleteObject", definition)


class MSKTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fake_boto3 = types.ModuleType("boto3")
        fake_boto3.resource = lambda service: None
        fake_boto3.client = lambda service: None
        sys.modules["boto3"] = fake_boto3

        signer = types.ModuleType("aws_msk_iam_sasl_signer")
        signer.MSKAuthTokenProvider = object
        sys.modules["aws_msk_iam_sasl_signer"] = signer

        kafka = types.ModuleType("kafka")
        kafka.KafkaProducer = object
        sys.modules["kafka"] = kafka
        net = types.ModuleType("kafka.net")
        sasl = types.ModuleType("kafka.net.sasl")
        oauth = types.ModuleType("kafka.net.sasl.oauth")
        oauth.AbstractTokenProvider = object
        sys.modules["kafka.net"] = net
        sys.modules["kafka.net.sasl"] = sasl
        sys.modules["kafka.net.sasl.oauth"] = oauth

        cls.consumer = load_module(
            "msk_consumer",
            TASK_ROOT / "assets/msk/lambda/consumer.py",
        )
        cls.alert_consumer = load_module(
            "msk_alert_consumer",
            TASK_ROOT / "assets/msk/lambda/alert_consumer.py",
        )

    def setUp(self):
        os.environ["ALERT_TOPIC"] = "wsc2026-sensor-alert"

    def test_normal_record_is_stored_without_alert_publish(self):
        table = FakeTable()
        producer = FakeProducer()
        item = {
            "sensorId": "SENSOR-001",
            "timestamp": "2026-06-01T18:28:24+09:00",
            "temperature": 64.6,
            "humidity": 50.0,
            "location": "factory-a",
        }

        alerted = self.consumer.process_item(item, table, producer)

        self.assertFalse(alerted)
        self.assertEqual("NORMAL", table.items[0]["status"])
        self.assertEqual("64.6", table.items[0]["temperature"])
        self.assertEqual([], producer.messages)

    def test_alert_record_is_stored_and_published_once(self):
        table = FakeTable()
        producer = FakeProducer()
        item = {
            "sensorId": "SENSOR-003",
            "timestamp": "2026-06-01T18:28:24+09:00",
            "temperature": 85.1,
            "humidity": 48.7,
            "location": "factory-a",
        }

        alerted = self.consumer.process_item(item, table, producer)

        self.assertTrue(alerted)
        self.assertEqual("ALERT", table.items[0]["status"])
        self.assertEqual(1, len(producer.messages))
        self.assertEqual("wsc2026-sensor-alert", producer.messages[0][0])

    def test_alert_consumer_publishes_sns_and_s3(self):
        fake_sns = types.SimpleNamespace(calls=[])
        fake_sns.publish = lambda **kwargs: fake_sns.calls.append(kwargs)
        fake_s3 = types.SimpleNamespace(calls=[])
        fake_s3.put_object = lambda **kwargs: fake_s3.calls.append(kwargs)
        self.alert_consumer.sns = fake_sns
        self.alert_consumer.s3 = fake_s3
        os.environ["SNS_TOPIC_ARN"] = "arn:aws:sns:region:account:topic"
        os.environ["S3_BUCKET"] = "alert-bucket"
        item = {
            "sensorId": "SENSOR-003",
            "timestamp": "2026-06-01T18:28:24+09:00",
            "status": "ALERT",
        }
        event = {
            "records": {
                "wsc2026-sensor-alert-0": [
                    {"value": base64.b64encode(json.dumps(item).encode()).decode()}
                ]
            }
        }

        result = self.alert_consumer.handler(event, None)

        self.assertEqual({"processed": 1}, result)
        self.assertEqual(1, len(fake_sns.calls))
        self.assertEqual(1, len(fake_s3.calls))
        self.assertTrue(fake_s3.calls[0]["Key"].startswith("alert/SENSOR-003/2026-06-01/"))


if __name__ == "__main__":
    unittest.main()
