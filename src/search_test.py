import os
import sys

# 1. 核心同步：必须在 import chromadb 之前打上 SQLite 补丁
__import__('pysqlite3')
sys.modules['sqlite3'] = sys.modules.pop('pysqlite3')

from dotenv import load_dotenv
from openai import OpenAI
import chromadb

load_dotenv()

# 2. 同步 API 配置
client = OpenAI(
    api_key=os.environ["API_KEY"], 
    base_url=os.environ["BASE_URL"]
)

# 注意：这里建议像 build_index.py 一样加上默认模型名 "BAAI/bge-m3"
# 防止因为 .env 里没写 EMB_MODEL 导致报错
emb_model = os.environ.get("EMB_MODEL", "BAAI/bge-m3")

# 连接本地 Chroma 数据库（保证 path="chroma" 与你建库时一致）
col = chromadb.PersistentClient(path="chroma").get_collection("runbooks")

q = "我的浏览器检测不到数据了"
print(f"正在检索问题: {q} \n")

# 把问题转向量
vec = client.embeddings.create(model=emb_model, input=[q]).data[0].embedding

# 查询最相关的 5 个结果
r = col.query(query_embeddings=[vec], n_results=5)

# 遍历打印结果
for i, (doc, meta, dist) in enumerate(zip(r["documents"][0], r["metadatas"][0], r["distances"][0]), 1):
    print(f"--- Top{i} {meta['source']} 距离={dist:.4f} ---")
    print(doc[:200])
    print("-" * 40)
