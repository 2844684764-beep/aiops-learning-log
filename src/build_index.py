# build_index.py —— 把 corpus 里的文档切块、转向量、存进 Chroma
import os
import re
import glob
import json
import sys

__import__('pysqlite3')
sys.modules['sqlite3'] = sys.modules.pop('pysqlite3')

from dotenv import load_dotenv
from openai import OpenAI
import chromadb


load_dotenv()

client = OpenAI(api_key=os.environ["API_KEY"], base_url=os.environ["BASE_URL"])
EMB_MODEL = os.environ.get("EMB_MODEL", "BAAI/bge-m3")

CORPUS_DIR = "corpus"
DB_DIR = "chroma"
MAX_CHARS = 800        # 每块最多 800 字
MIN_CHARS = 80         # 小于 80 字的块丢掉（多半是标题）


def split_markdown(text: str):
    """按二级标题切分。比按固定长度硬切好，因为语义是完整的。"""
    # 用 ## 作为分隔符切开
    parts = re.split(r"\n(?=## )", text)
    chunks = []
    for p in parts:
        p = p.strip()
        if len(p) < MIN_CHARS:
            continue
        # 太长的再按段落切
        if len(p) <= MAX_CHARS:
            chunks.append(p)
        else:
            buf = ""
            for para in p.split("\n\n"):
                if len(buf) + len(para) > MAX_CHARS and buf:
                    chunks.append(buf.strip())
                    buf = para
                else:
                    buf += "\n\n" + para
            if buf.strip():
                chunks.append(buf.strip())
    return chunks


def embed(texts):
    """调 API 把文字变成向量，一次最多 32 条，防止请求过大"""
    vectors = []
    for i in range(0, len(texts), 32):
        batch = texts[i:i + 32]
        resp = client.embeddings.create(model=EMB_MODEL, input=batch)
        vectors.extend([d.embedding for d in resp.data])
    return vectors


def main():
    # 每次重建都清空，避免重复
    if os.path.exists(DB_DIR):
        import shutil
        shutil.rmtree(DB_DIR)

    chroma = chromadb.PersistentClient(path=DB_DIR)
    col = chroma.create_collection(name="runbooks", metadata={"hnsw:space": "cosine"})

    ids, docs, metas = [], [], []
    for path in sorted(glob.glob(os.path.join(CORPUS_DIR, "*.md"))):
        name = os.path.basename(path)
        text = open(path, encoding="utf-8").read()
        chunks = split_markdown(text)
        for i, c in enumerate(chunks):
            ids.append(f"{name}#{i}")
            docs.append(c)
            metas.append({"source": name, "chunk": i})
        print(f"{name}: {len(chunks)} 块")

    print(f"总共 {len(docs)} 块，开始转向量...")
    vecs = embed(docs)

    col.add(ids=ids, documents=docs, embeddings=vecs, metadatas=metas)
    print(f"入库完成，共 {col.count()} 条")

    with open("corpus_stats.json", "w", encoding="utf-8") as f:
        json.dump({"chunks": len(docs), "sources": len(glob.glob(f'{CORPUS_DIR}/*.md'))}, f, ensure_ascii=False)


if __name__ == "__main__":
    main()
