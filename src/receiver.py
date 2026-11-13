# receiver.py —— 接收 Alertmanager 推来的告警，存成一行行 JSON
import json
import datetime

from fastapi import FastAPI, Request

app = FastAPI(title="alert-receiver")
LOG = "/home/shawny/aiops/alerts.log"


@app.post("/alert")
async def receive(req: Request):
    body = await req.json()
    for a in body.get("alerts", []):
        line = {
            "time": datetime.datetime.now().isoformat(timespec="seconds"),
            "status": a.get("status"),                       # firing / resolved
            "name": a.get("labels", {}).get("alertname"),
            "severity": a.get("labels", {}).get("severity"),
            "summary": a.get("annotations", {}).get("summary"),
            "detail": a.get("annotations", {}).get("description"),
        }
        text = json.dumps(line, ensure_ascii=False)
        print(text, flush=True)                # 打印到屏幕
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(text + "\n")               # 同时落盘
    return {"ok": True}
