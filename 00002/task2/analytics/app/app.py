import json, os, random, uuid
from datetime import datetime, timezone
import boto3
from flask import Flask, jsonify
app=Flask(__name__); stream=os.environ["STREAM_NAME"]; kinesis=boto3.client("kinesis",region_name=os.environ["AWS_REGION"])
products=[("Laptop",1200000),("Mouse",25000),("Keyboard",55000),("Monitor",350000),("Headset",89000)]
def order():
    name,price=random.choice(products)
    return {"order_id":str(uuid.uuid4()),"product_name":name,"price":price,"quantity":random.randint(1,5),"event_time":datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")}
@app.get("/health")
def health(): return jsonify(status="healthy")
@app.post("/order")
def one():
    value=order(); kinesis.put_record(StreamName=stream,Data=json.dumps(value),PartitionKey=value["order_id"]); return jsonify(value),201
@app.post("/orders/generate")
def many():
    values=[order() for _ in range(10)]; kinesis.put_records(StreamName=stream,Records=[{"Data":json.dumps(v),"PartitionKey":v["order_id"]} for v in values]); return jsonify(generated=10,orders=values),201
