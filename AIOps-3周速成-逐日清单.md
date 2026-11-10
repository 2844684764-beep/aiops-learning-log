# AIOps 三周速成 · 逐日清单

> 用法：每天只做当天那一格，做完打勾。周日复盘时如果发现某天没打勾，**砍功能，不要延期**。
>
> 总投入：工作日 1.5h × 15 天 + 周末 4.5h × 6 天 ≈ 50h（含缓冲）
>
> 唯一不可砍的环节：**第 2 周的评测**。没有数字，项目在面试里等于零。

---

## 第 0 天 · 准备（2h）

- [ ] 一台 2C4G 机器（云主机或本地 WSL2），装好 Docker + docker compose
- [ ] 装 VS Code + Remote-SSH（连云主机）或 Dev Containers
- [ ] 申请 LLM API key，跑通一次 hello world（能打印回复即可）
- [ ] 收集 15–20 篇语料：runbook、故障复盘、官方文档摘要（脱敏后使用）
- [ ] 建 git 仓库，README 先写三行目标
- [ ] 装 `tmux`，学会 `tmux new -s work` / `Ctrl-b d` / `tmux a`

> 语料找不到就用公开的 SRE 文档和自己的学习笔记，别卡在这一步。

---

## 第 1 周 · 让它「看得见」

目标：一个会出故障、能被观测、能触发告警的小系统。

### D1 · 1.5h
- [ ] 写一个 30 行 FastAPI 服务，暴露 `/metrics`，加一个可人为拖慢的接口 `/slow`
- [ ] 产出：`curl localhost:8000/metrics` 能看到指标

### D2 · 1.5h
- [ ] docker compose 起 Prometheus + Grafana，采集这个服务
- [ ] 产出：一个 dashboard，含 QPS、P95 延迟、错误率三个面板

### D3 · 1.5h
- [ ] 服务日志输出结构化 JSON 到文件（字段：ts、level、trace_id、path、latency_ms、error）
- [ ] 产出：`jq '.latency_ms' app.log | head` 能解析

### D4 · 1.5h
- [ ] 写 3 条告警规则：错误率 > 5%、P95 > 500ms、实例消失
- [ ] Prometheus 配 webhook，指向你自己写的 Python 接收器
- [ ] 产出：告警能打到接收器并打印告警内容

### D5 · 1.5h
- [ ] 用 `tc` 造 200ms 网络延迟、`stress-ng` 打满 CPU
- [ ] 记录每次故障时指标怎么变、多久触发告警
- [ ] 产出：一份「故障 → 指标变化 → 告警时间」对照记录

### D6 · 周六 4.5h
- [ ] 补 Linux 四件套：`top` / `ss` / `iostat` / `journalctl`，只学这四类问题
- [ ] 手写一页 cheat sheet：每类问题「看哪 3 个指标 → 异常长什么样 → 下一步命令」
- [ ] 补 D1–D5 的欠账

### D7 · 周日 4.5h
- [ ] 周复盘：写「这周我搭了什么、卡在哪、指标长什么样」
- [ ] 验收：能在 1 分钟内回答「现在系统健康吗，依据是哪三个指标」
- [ ] 把 dashboard 截图存进仓库 `docs/`

---

## 第 2 周 · 让它「说得对」

目标：一个带评测的 RAG。**这周是整个三周的重心。**

### D8 · 1.5h
- [ ] 语料按标题层级切分（不要固定长度硬切），用 embedding 入 Chroma
- [ ] 产出：输入一个问题，能检索出 top-5 片段

### D9 · 1.5h
- [ ] 接 LLM，强制 JSON 输出：`{answer, citations, confidence}`
- [ ] 用 pydantic 校验，解析失败就重试一次
- [ ] 产出：20 条测试输入里至少 18 条格式合法

### D10 · 1.5h
- [ ] 建 20 条评测问题：15 条有答案、**5 条文档里没有答案**
- [ ] 写成 `eval/questions.json`，每条标注期望来源文档
- [ ] 产出：评测集文件

### D11 · 1.5h
- [ ] 写打分脚本：recall@5 + 答案正确率（人工标 0/1/2）+ 拒答正确率
- [ ] 产出：跑出第一版数字（比如 recall@5 = 0.62），记进 README

### D12 · 1.5h
- [ ] 调优第一轮：改切分粒度、加关键词混合检索（BM25 + jieba）
- [ ] 记录每次改动的 delta

### D13 · 周六 4.5h
- [ ] 调优第二轮：加「不知道就说不知道」的系统提示，修无答案样本的误答
- [ ] 把 RAG 包成一个函数 `answer(question) -> dict`
- [ ] 产出：recall@5 ≥ 0.8，5 条无答案里至少 4 条正确拒答

### D14 · 周日 4.5h
- [ ] 冻结 RAG 版本，记录最终数字（这是你要写进简历的那组数）
- [ ] 周复盘

---

## 第 3 周 · 串起来 + 包装

目标：一条能演示的完整链路。

### D15 · 1.5h
- [ ] 写「上下文收集器」：收到告警 → 查前后 10 分钟指标 + grep 日志 + 检索 runbook
- [ ] 产出：一次调用返回结构化上下文（指标 / 日志摘要 / 相关文档）

### D16 · 1.5h
- [ ] 把上下文喂给 LLM，输出：3 条根因假设（带可能性）+ 建议动作 + 依据
- [ ] 产出：分析结果可读、每条结论都能指回原始数据

### D17 · 1.5h
- [ ] 包成 CLI：`ops-helper analyze --alert xxx`
- [ ] 危险动作只打印不执行，必须 `--confirm` 才真跑
- [ ] 产出：端到端能跑一遍

### D18 · 1.5h
- [ ] 故障注入实验 ×10：每次记录「有助手 / 没助手」的定位耗时
- [ ] 产出：10 行实验记录

### D19 · 1.5h
- [ ] 算 MTTR 对比，做成一张表进 README
- [ ] 产出：平均定位时间从 X 分钟降到 Y 分钟

### D20 · 周六 4.5h
- [ ] 录 90 秒 demo（OBS 或系统自带录屏）
- [ ] 写 README：架构图、部署方式、评测数据、明确写出「局限」
- [ ] 仓库整理干净，删掉临时脚本

### D21 · 周日 4.5h
- [ ] 写简历一页（用下面的模板）
- [ ] 准备面试三问：召回怎么调、误操作怎么防、怎么证明有用
- [ ] 总复盘：三周里哪一步最费时间，下次怎么省

---

## 工具清单

### 一、环境与开发（一次性）

| 用途 | 主选 | 备选 / 说明 |
|---|---|---|
| 容器 | Docker Engine + compose | Windows 用 WSL2 + Docker Desktop |
| 远程开发 | VS Code + Remote-SSH | 或 Dev Containers |
| 会话保持 | tmux | 云主机必装，断线不丢任务 |
| 版本管理 | git + GitHub | 私有仓库即可 |
| Python 依赖 | `uv` | 比 pip 快 10 倍；不想换就 `venv + pip` |
| 代码质量 | `ruff` | 一个顶 flake8 + black + isort |
| 测试 | `pytest` | 只写关键路径，别追求覆盖率 |

### 二、第 1 周：可观测 + 故障注入

| 用途 | 主选 | 坑 |
|---|---|---|
| 指标采集 | Prometheus（docker 镜像） | 别一上来搞 Thanos/联邦 |
| 主机指标 | `node_exporter` | 可选，本机实验可不装 |
| 可视化 | Grafana | dashboard 用现成模板改，别从零画 |
| 应用指标 | Python `prometheus-client` | 用 Histogram 而不是 Summary，P95 才准 |
| 日志 | Python `logging` + JSON formatter，`jq` 查询 | **三周版别装 ELK/Loki** |
| 故障注入 | `stress-ng`、`tc`（iproute2）、`fallocate` | 在容器里注入更安全 |
| 排查工具 | `top`/`htop`、`vmstat`、`iostat`（sysstat）、`ss`、`lsof`、`strace`、`journalctl` | Linux 性能工具全景图搜 Brendan Gregg |

### 三、第 2 周：LLM + RAG

| 用途 | 主选 | 备选 / 说明 |
|---|---|---|
| 模型 API | DeepSeek / 通义 / 智谱（国内直连、便宜） | OpenAI 需网络条件；统一用 `openai` SDK 兼容层 |
| 本地模型（合规/省钱） | Ollama + `qwen2.5:7b` | 三周版建议先用 API，省时间 |
| 结构化输出 | 原生 JSON mode / function calling + `pydantic` 校验 | 再不行上 `instructor` |
| 文本切分 | **自己写 50 行**（按标题层级） | 别用框架的固定长度 splitter |
| Embedding | API embedding，或本地 `bge-m3` / `bge-small-zh` | 中文场景优先 bge 系列 |
| 向量库 | Chroma（`chromadb`，零部署） | 备选 Qdrant（docker） |
| 关键词检索 | `rank_bm25` + `jieba` 分词 | 混合检索是提升召回最便宜的一招 |
| 重排（可选） | `bge-reranker-base` | 时间不够直接跳过 |
| 重试 | `tenacity` | LLM 调用必须带退避重试 |
| 调用日志 | 自己打 JSON：model、tokens、latency、cost | 别上 Langfuse，三周版太重 |

### 四、第 3 周：串联 + 评测 + 交付

| 用途 | 主选 | 说明 |
|---|---|---|
| 评测脚本 | **手写 Python** | `ragas` 依赖多容易卡，三周版不用 |
| 评测指标 | recall@k、MRR、答案分 0/1/2、拒答正确率 | 四个够用 |
| 数据格式 | JSON + Markdown 表格 | 别上数据库 |
| CLI | `argparse` 或 `typer` | 别上 Web 框架，CLI 演示更快 |
| 配置/密钥 | `.env` + `python-dotenv` | key 绝对不能进 git |
| 架构图 | Excalidraw / draw.io | 手绘风格反而好看 |
| 录屏 | OBS Studio / Windows Xbox Game Bar / macOS QuickTime | 90 秒，别配 BGM |

### 五、明确不要碰（三周版）

- ❌ LangChain / LlamaIndex —— 抽象层会吃掉你一半时间
- ❌ Kubernetes / minikube —— 这版砍掉
- ❌ ELK / Loki 集群 —— 用文件 + jq
- ❌ Alertmanager 全套 —— 自己写 webhook 更可控
- ❌ 各种「AIOps 平台」商业 demo —— 学不到东西
- ❌ 论文和算法课 —— 三周版不做异常检测算法
- ❌ 一堆付费课 —— 官方文档 + 动手就够了

### 六、成本

- 云主机：学生机或按量，通常几十元以内/月
- LLM API：这个项目跑完，通常几元到几十元
- 其余全部开源免费

---

## 评测表模板（直接抄进 `eval/questions.json`）

| # | 问题 | 期望来源 | 是否有答案 | recall@5 | 答案分(0/1/2) | 备注 |
|---|---|---|---|---|---|---|
| 1 | 服务 P95 突然升高怎么排查 | runbook-latency.md | 是 | | | |
| 2 | 磁盘满了会触发哪条告警 | runbook-disk.md | 是 | | | |
| 3 | 数据库连接池配置在哪 | —— | 否 | | | 应拒答 |
| … | | | | | | |

统计口径：
- `recall@5` = 期望文档出现在 top-5 的比例
- `答案正确率` = 答案分 ≥ 1 的比例（只统计有答案的题）
- `拒答正确率` = 无答案题里正确说「不知道」的比例

---

## 每日三行日志（模板）

```
D__ 日期：
做了什么：
卡在哪：
明天第一步：
```

---

## 90 秒演示脚本（照着念）

> 这是我做的一个最小 AIOps 闭环。左边是我注入的一次故障——订单服务 P95 从 80ms 涨到 900ms，Prometheus 触发告警，打到我的接收器。
>
> 接收器自动收集上下文：前后 10 分钟指标、这期间的错误日志、以及检索到的相关 runbook。
>
> 模型输出三条根因假设，第一条是数据库连接池耗尽，依据是连接数指标和日志里的 timeout 关键字。它建议调大连接池并重启，我只做了 dry-run，实际执行需要人工确认。
>
> 我用 10 次注入实验测过：平均定位时间从 23 分钟降到 9 分钟。RAG 的 recall@5 是 0.86，20 条评测题里有 5 条是故意没有答案的，它拒答对了 4 条。

---

## 简历模板（填数字）

> 三周内独立实现最小 AIOps 闭环：自建 FastAPI 服务 + Prometheus/Grafana 可观测与告警，编写告警上下文自动收集器（指标 + 日志 + runbook 检索）；基于 __ 篇运维文档构建 RAG，recall@5 = __，__ 条评测集含 __ 条无答案样本、拒答正确 __ 条；封装为带 dry-run 与人工确认的运维助手，__ 次故障注入实验中平均定位时间由 __ 分钟降至 __ 分钟。

面试被问「你才学三周」：

> 我知道三周不够，所以我只做了一条链路，把它做到底并且量了数据。K8s 和 IaC 我没碰，这块我进去再补。
