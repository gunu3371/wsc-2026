import json,os,uuid
from datetime import datetime,timezone
import boto3
from flask import Flask,jsonify,request
app=Flask(__name__); table=boto3.resource('dynamodb',region_name=os.environ.get('AWS_REGION')).Table(os.environ['TABLE_NAME'])
@app.get('/health')
def health(): return jsonify(status='ok')
@app.route('/v1/book',methods=['POST'])
def book():
 b=request.get_json(silent=True) or {}; bid=str(uuid.uuid4()); now=datetime.now(timezone.utc).isoformat(); item={'booking_id':bid,'client_id':b.get('client_id',''),'username':b.get('username',''),'email':b.get('email',''),'concert_name':b.get('concert_name',''),'created_at':now}; table.put_item(Item=item); print(json.dumps({'method':'POST','path':'/v1/book','booking_id':bid,'status':201}),flush=True); return jsonify(item),201
app.run(host='0.0.0.0',port=8080)
