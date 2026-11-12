# 服务代码（D1 起）

对应手册：[W1-第1周.md](../handbook/W1-第1周.md)

## 当前进度

| 天 | 内容 | 状态 |
|---|---|---|
| D1 | FastAPI 服务 + `/metrics` 指标 | ✅ |
| D2 | Prometheus + Grafana + 仪表盘 | ✅ |
| D3 | 结构化日志 + trace_id | ✅ |
| D4 | 告警 | ⬜ |

## 目录

```
src/
├── app.py                  # D1：业务服务，暴露 /metrics
├── requirements.txt
├── README.md
└── monitoring/             # D2：Prometheus + Grafana
    ├── docker-compose.yml
    ├── prometheus.yml
    ├── provisioning/
    └── dashboards/
```

## 怎么跑

```bash
cd ~/aiops
python3 -m venv .venv
source .venv/bin/activate
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
pip install -r requirements.txt

uvicorn app:app --host 0.0.0.0 --port 8000
```

监控栈另一个终端：

```bash
cd ~/aiops
docker compose up -d
```

## 接口

| 路径 | 作用 | 返回 |
|---|---|---|
| `/` | 正常接口 | `{"msg":"ok"}` |
| `/slow` | 故意慢 0.1–1 秒，制造延迟 | `{"msg":"slow"}` |
| `/error` | 故意返回 500，制造错误率 | `{"msg":"boom"}` + 500 |
| `/metrics` | Prometheus 抓取入口 | 纯文本指标 |

## 暴露的指标

| 指标 | 类型 | 含义 |
|---|---|---|
| `app_requests_total{path,status}` | Counter | 请求总数，按路径和状态码分组 |
| `app_latency_seconds{path}` | Histogram | 请求耗时分布，用来算 P95 |

## 访问地址

| 服务 | 地址 |
|---|---|
| 业务服务 | http://192.168.223.129:8000 |
| Prometheus | http://192.168.223.129:9090 |
| Grafana | http://192.168.223.129:3000 |
