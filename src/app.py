# app.py —— 一个会暴露指标的小服务
import time
import random
import logging
import json
import uuid
from starlette.middleware.base import BaseHTTPMiddleware

# ── 日志配置 ────────────────────────────────────────────
class JsonFormatter(logging.Formatter):
    """把日志格式化成一行 JSON"""
    def format(self, record):
        base = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
            "level": record.levelname,
            "msg": record.getMessage(),
        }
        # 把 extra 里传的自定义字段也带上
        for k in ("trace_id", "path", "status", "latency_ms", "client"):
            v = getattr(record, k, None)
            if v is not None:
                base[k] = v
        return json.dumps(base, ensure_ascii=False)

handler = logging.FileHandler("/home/shawny/aiops/app.log", encoding="utf-8")
handler.setFormatter(JsonFormatter())

log = logging.getLogger("app")
log.setLevel(logging.INFO)
log.addHandler(handler)
log.propagate = False      # 不要同时输出到屏幕，避免重复


# ── 访问日志中间件 ──────────────────────────────────────
class AccessLog(BaseHTTPMiddleware):
    """每个请求进出都记一条，自动带 trace_id 和耗时"""
    async def dispatch(self, request, call_next):
        if request.url.path == "/metrics":     # 抓指标太频繁，不记
            return await call_next(request)

        start = time.time()
        trace_id = request.headers.get("x-trace-id") or uuid.uuid4().hex[:8]
        response = await call_next(request)
        cost_ms = (time.time() - start) * 1000

        log.info("request", extra={
            "trace_id": trace_id,
            "path": request.url.path,
            "status": response.status_code,
            "latency_ms": round(cost_ms, 1),
            "client": request.client.host if request.client else "-",
        })
        response.headers["x-trace-id"] = trace_id   # 回传给调用方，方便串联
        return response

from fastapi import FastAPI
from fastapi.responses import Response, JSONResponse
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = FastAPI(title="aiops-demo")
app.add_middleware(AccessLog)
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
