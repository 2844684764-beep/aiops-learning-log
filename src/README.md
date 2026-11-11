# 鏈嶅姟浠ｇ爜锛圖1 璧凤級

瀵瑰簲鎵嬪唽锛歔W1-绗?鍛?md](../handbook/W1-绗?鍛?md)

## 褰撳墠杩涘害

| 澶?| 鍐呭 | 鐘舵€?|
|---|---|---|
| D1 | FastAPI 鏈嶅姟 + `/metrics` 鎸囨爣 | 鉁?|
| D2 | Prometheus + Grafana | 猬?|
| D3 | 缁撴瀯鍖栨棩蹇?| 猬?|

## 鎬庝箞璺?
```bash
cd ~/aiops
python3 -m venv .venv
source .venv/bin/activate
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
pip install -r requirements.txt

uvicorn app:app --host 0.0.0.0 --port 8000
```

## 鎺ュ彛

| 璺緞 | 浣滅敤 | 杩斿洖 |
|---|---|---|
| `/` | 姝ｅ父鎺ュ彛 | `{"msg":"ok"}` |
| `/slow` | 鏁呮剰鎱?0.1鈥? 绉掞紝鍒堕€犲欢杩?| `{"msg":"slow"}` |
| `/error` | 鏁呮剰杩斿洖 500锛屽埗閫犻敊璇巼 | `{"msg":"boom"}` + 500 |
| `/metrics` | Prometheus 鎶撳彇鍏ュ彛 | 绾枃鏈寚鏍?|

## 鏆撮湶鐨勬寚鏍?
| 鎸囨爣 | 绫诲瀷 | 鍚箟 |
|---|---|---|
| `app_requests_total{path,status}` | Counter | 璇锋眰鎬绘暟锛屾寜璺緞鍜岀姸鎬佺爜鍒嗙粍 |
| `app_latency_seconds{path}` | Histogram | 璇锋眰鑰楁椂鍒嗗竷锛岀敤鏉ョ畻 P95 |
