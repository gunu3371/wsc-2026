import json, os, random, uuid
from datetime import datetime, timezone
import boto3
from flask import Flask, jsonify
app=Flask(__name__); stream=os.environ["STREAM_NAME"]; client=boto3.client("kinesis",region_name=os.environ["AWS_REGION"])
products=[("Laptop",1200000),("Mouse",25000),("Keyboard",55000),("Monitor",350000),("Headset",89000)]
def order():
    name,price=random.choice(products); return {"order_id":str(uuid.uuid4()),"product_name":name,"price":price,"quantity":random.randint(1,5),"event_time":datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")}
def put(o): client.put_record(StreamName=stream,Data=json.dumps(o),PartitionKey=o["order_id"])
@app.get("/health")
def health(): return jsonify(status="healthy")
@app.post("/order")
def one(): o=order();put(o);return jsonify(o),201
@app.post("/orders/generate")
def many(): items=[order() for _ in range(10)];[put(x) for x in items];return jsonify(generated=10,orders=items),201

