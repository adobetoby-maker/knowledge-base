# Full RAG Pipeline with a Local Model

## Architecture Overview

RAG (Retrieval-Augmented Generation) separates knowledge storage from language generation. The model doesn't need to memorize facts — it reads them at inference time from retrieved chunks. This makes knowledge updatable without retraining and keeps hallucinations bounded to what you actually retrieved.

The pipeline has two distinct phases: **ingest** (runs offline, once per document update) and **query** (runs online, per user request). Keep them separate. Don't re-embed documents at query time.

## Ingest Pipeline

**1. Parse**
Extract raw text from source format. For PDFs: use `pdfplumber` (better than `pypdf` for tables) or `unstructured`. For Word docs: `python-docx`. For HTML: strip tags with `BeautifulSoup`, preserve heading structure. Preserve metadata: filename, page number, section title, last modified date.

**2. Chunk**
Split text into overlapping segments. Target 400–600 tokens per chunk. Use a recursive character splitter: try paragraph breaks first, then sentence boundaries, then word boundaries. Apply 10–15% overlap between adjacent chunks (overlap the tail of chunk N into the head of chunk N+1). Never overlap more than 20% — you'll retrieve the same content twice.

Store chunk metadata: `{doc_id, chunk_index, page, section, text, token_count}`.

**3. Embed**
Run every chunk through your embedding model. Keep the model consistent across ingest and query — even a version change (e.g., `nomic-embed-text:v1` vs `v1.5`) shifts the embedding space and breaks retrieval. Use a local embedding model via Ollama (`nomic-embed-text`, `mxbai-embed-large`) to keep data on-premise.

Batch embed in groups of 32–64 chunks for throughput. Embedding is cheap; don't throttle it.

**4. Store**
Write vectors to a local vector store. For small corpora (<100k chunks): FAISS in-process is fast and zero-infrastructure. For larger corpora or multi-user: pgvector (Supabase) or Chroma. Store the full chunk text alongside the vector — you'll need it at query time without a separate DB lookup.

## Query Pipeline

**1. Embed the Query**
Run the user's question through the same embedding model. Single embedding call, ~10ms.

**2. Vector Search**
Retrieve top-k=10 candidate chunks by cosine similarity. Fetch more than you need — you'll prune in the next step. Don't use k=3 here; retrieval recall matters more than precision at this stage.

**3. Rerank**
Pass the query + each candidate chunk to a cross-encoder reranker (`bge-reranker-base` or `cross-encoder/ms-marco-MiniLM-L-6-v2`). Cross-encoders score query-document pairs jointly, which is more accurate than independent cosine scores. Select top 3–4 by reranker score.

If no reranker is available, filter by similarity threshold (>0.65) and take top 4.

**4. Generate**
Inject the reranked chunks into the generation prompt with source labels. Pass to your local generation model (7B+). Constrain the answer to only information present in the retrieved chunks.

## Chunking Overlap Deep Dive

Overlap exists because real sentences don't respect chunk boundaries. Without overlap, a question answered by a sentence that straddles two chunks retrieves neither chunk cleanly — the first chunk has the setup, the second has the conclusion, but neither contains enough context to answer alone.

With 15% overlap, both chunks contain the boundary sentence. The retrieval system may return both, but even returning one is enough.

Overlap increases storage by ~10–15%. This is almost always worth it.

## Hybrid Search

Pure vector search misses exact keyword matches (product IDs, names, codes). Combine with BM25 keyword search and merge via reciprocal rank fusion. See `local--hybrid-search.md` for the full pattern.

## Key Rules

- Maintain strict ingest/query separation — never re-embed at query time.
- Use identical embedding model version for both ingest and query; any drift breaks cosine similarity.
- Store chunk text in the vector store record — avoid a separate DB roundtrip at query time.
- Apply 10–15% chunk overlap; zero-overlap pipelines have noticeably lower recall.
- Retrieve k=10 then rerank to top 3–4; don't retrieve only 3 and skip reranking.
- Log retrieved chunk IDs and similarity scores per query — essential for diagnosing retrieval failures.
