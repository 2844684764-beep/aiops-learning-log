# 监控栈（D2 起）

Prometheus + Grafana，用 Docker Compose 跑。**仪表盘不走界面，走文件**——Grafana 启动时自动读 JSON 加载。

## 目录

```
monitoring/
├── docker-compose.yml           # 两个容器 + 挂载
├── prometheus.yml               # 抓取配置
├── provisioning/
│   └── dashboards.yml           # 告诉 Grafana 去哪读仪表盘
└── dashboards/
    └── app-overview.json        # 仪表盘本体（3 个面板）
```

## 为什么用文件而不是点界面

1. **可复现**：删了容器重来，仪表盘还在
2. **可版本控制**：JSON 能进 git，界面上的点击进不了
3. **避开 UI bug**：Grafana 面板编辑器在部分版本会报 `insertBefore` 错误，文件方式完全绕开

改 JSON → 保存 → 最多 30 秒（`updateIntervalSeconds`）Grafana 自动重载，不用重启容器。

## 启动

```bash
cd ~/aiops
docker compose up -d
```

## ⚠️ 一个必须知道的坑：目录权限

Grafana 容器以 **uid 472** 运行。它要读宿主机的 `dashboards/` 目录，路径上每一级都必须允许 uid 472 **穿越**：

```bash
chmod 711 /home/shawny                      # 允许穿越（不能列目录）
chmod -R a+rX dashboards provisioning       # 允许读
```

默认 RHEL 的家目录是 `700`，不改就是 `permission denied`。

这就是容器化最常见的坑之一：**容器里的用户和宿主机的用户不是一回事**。

## 三个面板

| 面板 | 查询 | 单位 |
|---|---|---|
| QPS | `sum(rate(app_requests_total[1m]))` | reqps |
| P95 延迟 | `histogram_quantile(0.95, sum(rate(app_latency_seconds_bucket[1m])) by (le))` | s |
| 5xx 错误率 | `sum(rate(app_requests_total{status=~"5.."}[1m])) / sum(rate(app_requests_total[1m]))` | percentunit |

面板没有写死数据源，用的是 Grafana 的**默认数据源**。如果打开后显示「Datasource not found」，去 Connections → Data sources → 你的 Prometheus → 点 **Set as default**。

## 验证

```bash
curl localhost:3000/api/health          # {"database":"ok"}
curl localhost:9090/-/healthy
docker logs grafana 2>&1 | grep -i provision
# 应看到：starting to provision dashboards / finished to provision dashboards
```
