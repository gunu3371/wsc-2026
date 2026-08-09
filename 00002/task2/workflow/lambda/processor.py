import csv, io, json, os, re
from datetime import datetime, timezone
from decimal import Decimal
import boto3
FIELDS=["examDate","studentId","name","className","korean","english","math","science","history"]
SCORES=["korean","english","math","science","history"]
s3=boto3.client("s3"); ddb=boto3.resource("dynamodb")
def validate(row):
    if any(not (row.get(f) or "").strip() for f in FIELDS): return "MISSING_FIELD"
    try:
        datetime.strptime(row["examDate"].strip(),"%Y-%m-%d")
    except ValueError: return "INVALID_DATE"
    for f in SCORES:
        v=row[f].strip()
        if not re.fullmatch(r"[+-]?\d+",v): return "INVALID_FORMAT"
        if not 0 <= int(v) <= 100: return "INVALID_SCORE"
def grade(avg):
    return "A" if avg>=90 else "B" if avg>=80 else "C" if avg>=70 else "D" if avg>=60 else "F"
def handler(event,context):
    bucket=os.environ["S3_BUCKET"]; key=event.get("key","")
    if not key.startswith("input/"): return {"statusCode":400,"processed":0,"errors":0,"key":key}
    rows=list(csv.DictReader(io.StringIO(s3.get_object(Bucket=bucket,Key=key)["Body"].read().decode("utf-8"))))
    table=ddb.Table(os.environ["DDB_TABLE"]); ok=bad=0; stamp=datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    for row in rows:
        reason=validate(row)
        if reason:
            sid=(row.get("studentId") or "unknown").strip(); body={"studentId":sid,"examDate":(row.get("examDate") or "").strip(),"error_reason":reason,"raw_data":row}
            s3.put_object(Bucket=bucket,Key=f"error/error_{stamp}_{sid}.json",Body=json.dumps(body,ensure_ascii=False).encode(),ContentType="application/json"); bad+=1
        else:
            values=[int(row[x]) for x in SCORES]; avg=Decimal(str(sum(values)/len(values)))
            item={k:v.strip() for k,v in row.items()}; item.update({x:Decimal(item[x]) for x in SCORES}); item.update({"average":avg,"grade":grade(avg),"createdAt":datetime.now(timezone.utc).isoformat()}); table.put_item(Item=item); ok+=1
    return {"statusCode":200,"processed":ok,"errors":bad,"key":key}

