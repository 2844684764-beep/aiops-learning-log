# app.py —— 一个会暴露指标的小服务
import time
import random

from fastapi import FastAPI
from fastapi.responses import Response, JSONResponse
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = FastAPI(title="aiops-demo")

# ── 两个指标 ────────────────────────────────────────────
# Counter：只增不减的计数器。这里按「路径」和「状态码」分组统计请求数
REQUESTS = Counter("app_requests_total", "请求总数", ["path", "status"])

# Histogram：直方图。记录每次请求耗时，用来算 P95（95% 的请求快于多少毫秒）
LATENCY = Histogram(
    "app_latency_seconds", "请求耗时（秒）", ["path"],
    buckets=(0.05, 0.1, 0.25, 0.5, 1, 2, 5),   # 分桶的边界，决定了精度
)


@app.get("/")
def index():
    """正常接口，很快返回"""
    with LATENCY.labels("/").time():        # 进入 with 时开始计时，退出时记录
        REQUESTS.labels("/", "200").inc()   # 计数 +1
    return {"msg": "ok"}


@app.get("/slow")
def slow():
    """慢接口，故意睡 0.1~1 秒，用来制造延迟故障"""
    with LATENCY.labels("/slow").time():
        time.sleep(random.uniform(0.1, 1.0))
        REQUESTS.labels("/slow", "200").inc()
    return {"msg": "slow"}


@app.get("/error")
def error():
    """错误接口，返回 500，用来制造错误率"""
    REQUESTS.labels("/error", "500").inc()
    return JSONResponse(status_code=500, content={"msg": "boom"})


@app.get("/metrics")
def metrics():
    """Prometheus 来抓数据时就访问这个路径"""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
