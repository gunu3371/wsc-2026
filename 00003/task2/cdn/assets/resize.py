import base64
import boto3
import io
import os
from datetime import datetime, timezone, timedelta
from urllib.parse import parse_qs

s3 = boto3.client("s3")

def handler(event, context):
    record = event["Records"][0]["cf"]
    request, response = record["request"], record["response"]
    if response.get("status") != "200": return response
    query = parse_qs(request.get("querystring", ""))
    width, height = int(query.get("w", ["1920"])[0]), int(query.get("h", ["1080"])[0])
    device = query.get("type", ["desktop"])[0]
    bucket = request["origin"]["s3"]["domainName"].split(".s3")[0]
    key = request["uri"].lstrip("/")
    original = s3.get_object(Bucket=bucket, Key=key)["Body"].read()
    try:
        from PIL import Image
        image = Image.open(io.BytesIO(original)); image.thumbnail((width, height)); out = io.BytesIO(); image.convert("RGB").save(out, "PNG"); body = out.getvalue()
    except ImportError:
        body = original
    stamp = datetime.now(timezone(timedelta(hours=9))).strftime("%Y%m%d_%H%M%S")
    filename = os.path.splitext(os.path.basename(key))[0]
    s3.put_object(Bucket=bucket, Key=f"resized/{device}_{filename}_{stamp}.png", Body=body, ContentType="image/png")
    response["body"] = base64.b64encode(body).decode(); response["bodyEncoding"] = "base64"; response["headers"]["content-type"] = [{"key":"Content-Type","value":"image/png"}]
    return response
