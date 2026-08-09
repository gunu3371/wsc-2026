import json, logging
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
logging.basicConfig(level=logging.INFO, format='%(message)s')
class H(BaseHTTPRequestHandler):
 def emit(self,level,message,count=1):
  for _ in range(count): print(json.dumps({"level":level,"message":message,"service":"log-generator"}),flush=True)
 def do_GET(self):
  p=urlparse(self.path); q=parse_qs(p.query)
  if p.path=="/health": body={"status":"ok"}
  elif p.path=="/burst":
   level=q.get("level",["INFO"])[0]; self.emit(level,"burst",int(q.get("count",[1])[0])); body={"emitted":int(q.get("count",[1])[0])}
  else:
   level=p.path.strip("/").upper(); self.emit(level, p.path); body={"level":level}
  b=json.dumps(body).encode(); self.send_response(200); self.send_header("Content-Type","application/json"); self.send_header("Content-Length",str(len(b))); self.end_headers(); self.wfile.write(b)
HTTPServer(("0.0.0.0",8080),H).serve_forever()

