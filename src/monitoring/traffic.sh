#!/usr/bin/env bash
# traffic.sh —— 持续给业务服务打流量，让仪表盘一直有数据
#
# 为什么需要：带标签的指标（app_requests_total 等）在第一次被调用前不会导出。
#            服务重启后如果没有请求，Grafana 面板就是一片空白。
#
# 用法：
#   bash traffic.sh            # 前台运行，Ctrl+C 停止
#   nohup bash traffic.sh > /tmp/traffic.log 2>&1 &    # 后台运行
#   pkill -f traffic.sh        # 停止

TARGET="${1:-localhost:8000}"
INTERVAL="${2:-2}"

echo "对 $TARGET 每 ${INTERVAL}s 打一轮流量，Ctrl+C 停止"

cleanup() {
  echo ""
  echo "已停止"
  exit 0
}
trap cleanup INT TERM

i=0
while true; do
  i=$((i + 1))

  curl -s -o /dev/null -m 3 "http://$TARGET/" || { echo "服务不可达，检查 uvicorn 是否在跑"; sleep 5; continue; }
  curl -s -o /dev/null -m 5 "http://$TARGET/slow"

  # 每 10 轮打一次错误，让 5xx 面板也有数据
  if [ $((i % 10)) -eq 0 ]; then
    curl -s -o /dev/null -m 3 "http://$TARGET/error"
  fi

  sleep "$INTERVAL"
done
