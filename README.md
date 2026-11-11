# 找工作 · AIOps 三周速成

目标：三周做出一个**能演示、有评测数据**的 AIOps 最小闭环，用于简历与面试。

## 从这里开始

**如果你是零基础，先看手册：**

| 文件 | 内容 |
|---|---|
| [handbook/00-总览.md](handbook/00-总览.md) | 运维在干什么、AI+运维是什么、五个必懂名词、工具速查表 |
| [handbook/W1-第1周.md](handbook/W1-第1周.md) | D1–D7：写出一个会生病、能被观测、会报警的小系统 |
| [handbook/W2-第2周.md](handbook/W2-第2周.md) | D8–D14：带评测数据的运维知识库问答（RAG） |
| [handbook/W3-第3周.md](handbook/W3-第3周.md) | D15–D21：串成闭环、量化效果、包装面试 |

每一天都是同一结构：**今天的目标 → 为什么做 → 用什么工具 → 具体步骤（命令+解释）→ 你会看到什么 → 卡住了看这里 → 做完检查**。

## 目录

| 路径 | 用途 |
|---|---|
| `handbook/` | **零基础手册**（主教材，逐日展开） |
| `AIOps-3周速成-逐日清单.md` | 精简版任务清单（打勾用） |
| `scripts/rhel-setup.sh` | RHEL 9 环境一键初始化脚本 |
| `notes/` | 每日复盘（D01–D21） |
| `docs/` | dashboard 截图、架构图、录屏 |
| `eval/` | 评测集与打分结果 |

## 环境

| 项 | 值 |
|---|---|
| 虚拟机 | VMware Workstation 17，RHEL 9.6，2 vCPU / 4 GB / 40 GB |
| 地址 | `192.168.223.129`（NAT） |
| 宿主机项目 | `C:\Users\28446\Desktop\找工作` |
| 虚拟机项目 | `~/aiops` |

## 进度

- [x] 环境搭建（Docker 29.9.3 / Compose v5.7.0 / EPEL / 镜像加速器）
- [x] D1 服务 + `/metrics`（[src/app.py](src/app.py) · [notes/D01.md](notes/D01.md)）
- [x] D2 Prometheus + Grafana + 仪表盘（[src/monitoring/](src/monitoring) · [notes/D02.md](notes/D02.md)）
- [ ] D3–D7 第 1 周
- [ ] 第 2 周
- [ ] 第 3 周

## 三周验收标准

| 周 | 验收 |
|---|---|
| 第 1 周 | 能在 1 分钟内说清「系统健康吗，依据是哪三个指标」 |
| 第 2 周 | recall@5 ≥ 0.8，5 条无答案样本至少 4 条正确拒答 |
| 第 3 周 | 端到端能跑通，有 10 次注入实验的 MTTR 对比数据 |

## 三条铁律

1. 每周必须有一个能跑的东西，跑不起来就砍功能，不延期
2. 评测环节不可砍——没有数字，项目在面试里等于零
3. 任何需要 2 小时以上才能跑起来的工具，三周版一律不用

## 常用命令

``` bash
# 虚拟机里
cd ~/aiops
source .venv/bin/activate

uvicorn app:app --host 0.0.0.0 --port 8000     # 起业务服务
uvicorn receiver:app --host 0.0.0.0 --port 8001 # 起告警接收器
docker compose up -d                            # 起 Prometheus + Grafana + Alertmanager

curl -s localhost:8000/metrics | grep app_      # 看指标
jq 'select(.latency_ms > 500)' app.log          # 筛慢请求
python ops_helper.py analyze --alert HighLatency # AI 分析
```
