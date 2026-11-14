# 服务代码（D1 起）

对应手册：[W1-第1周.md](../handbook/W1-第1周.md)

## 当前进度

| 天 | 内容 | 状态 |
|---|---|---|
| D1 | FastAPI 服务 + `/metrics` 指标 | ✅ |
| D2 | Prometheus + Grafana + 仪表盘 | ✅ |
| D3 | 结构化日志 + trace_id | ✅ |
| D4 | 告警（规则 + Alertmanager + 接收器） | ✅ |
| D5 | 故障注入 | ✅ |
| D8 | 语料切分 + bge-m3 向量入库 + top-5 检索验证 | ✅ |

## 目录

```
src/
├── app.py                  # D1：业务服务，暴露 /metrics
├── receiver.py             # D4：接收 Alertmanager 的告警
├── build_index.py          # D8：切块 + 转向量 + 存 Chroma
├── search_test.py          # D8：检索 top-5，验证召回
├── requirements.txt
├── README.md
└── monitoring/             # D2 起：Prometheus + Grafana + Alertmanager
    ├── docker-compose.yml
    ├── prometheus.yml
    ├── rules.yml           # D4：3 条告警规则
    ├── alertmanager.yml    # D4：告警路由
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

## D8：RAG 检索（第 2 周）

> 对应笔记：[notes/D08.md](../notes/D08.md) · 手册：[handbook/W2-第2周.md](../handbook/W2-第2周.md)

这两个脚本要放在虚拟机 `~/aiops` 根目录跑（脚本里用的是相对路径 `corpus/` 和 `chroma/`）：

```bash
cd ~/aiops
source .venv/bin/activate
pip install -r requirements.txt        # 已含 openai / chromadb / pysqlite3-binary

python build_index.py                  # corpus/*.md → 130 块 → chroma/
python search_test.py                  # 检索 top-5，打印距离
```

**这条必须记住**：RHEL 9 自带 sqlite 3.34.1，低于 chromadb 要求的 3.35.0，
所以两个脚本开头都有这段补丁，且**必须在 `import chromadb` 之前**：

```python
__import__('pysqlite3')
sys.modules['sqlite3'] = sys.modules.pop('pysqlite3')
```

`corpus/` 和 `chroma/` 都不进仓库（.gitignore）；语料来源见 [notes/D08.md](../notes/D08.md)。
