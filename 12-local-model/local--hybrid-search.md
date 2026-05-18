# Combining Vector and Keyword Search

## Why Neither Alone Is Enough

Vector search (dense retrieval) finds semantically related content even when the exact words differ. Ask "cardiovascular disease treatment" and it retrieves chunks about "heart disease therapy" — good. But ask for "SKU-4421" or "RFC 7231" and it fails — the model has no semantic anchor for arbitrary identifiers.

BM25 (sparse/keyword search) is the opposite: exact term matches score high, paraphrases score zero. It excels for product codes, proper nouns, technical identifiers, and quoted phrases. It fails for conceptual queries where vocabulary varies.

Hybrid search combines both signals. The result handles both exact-term lookup and semantic similarity within a single retrieval system.

## BM25 for Keyword Search

BM25 (Best Match 25) is a probabilistic ranking function built on TF-IDF with document length normalization. It scores documents by how many query terms they contain, weighted by term rarity across the corpus.

Use `rank_bm25` in Python or `lunr.js` in Node for lightweight in-process BM25. For production scale, Elasticsearch/OpenSearch have built-in BM25 scoring.

Pre-tokenize your corpus at ingest time (same tokenization used at query time). Lowercase, remove stopwords, optionally stem. Store the tokenized index alongside your vector store.

At query time: tokenize the query identically, run BM25, retrieve top-k ranked documents.

## Vector Search for Semantic Queries

Dense vector search uses embedding similarity (cosine or dot product). See `local--rag-pipeline.md` for full ingest and query pipeline details.

At query time: embed the query, retrieve top-k nearest vectors.

## Reciprocal Rank Fusion

RRF merges two ranked lists without needing calibrated scores from either. It only uses rank position, making it robust to score scale differences between BM25 (unnormalized float) and cosine similarity (0–1).

RRF formula for document `d` across ranked lists `L`:

```
RRF_score(d) = Σ_L  1 / (k + rank_L(d))
```

Where `k=60` is the standard constant (dampens the effect of top ranks, prevents any single list from dominating). Documents not present in a list get rank = ∞ (contributing 0).

Implementation:

```python
def reciprocal_rank_fusion(results_lists, k=60):
    scores = {}
    for results in results_lists:
        for rank, doc_id in enumerate(results, start=1):
            scores[doc_id] = scores.get(doc_id, 0) + 1 / (k + rank)
    return sorted(scores, key=lambda d: scores[d], reverse=True)
```

Pass `[bm25_ranked_ids, vector_ranked_ids]` and get a unified ranked list back.

## When Each Signal Dominates

**Keyword search dominates when:**
- Query contains rare identifiers (SKUs, model numbers, codes, names)
- User is searching for an exact phrase or quote
- Domain has specialized terminology the embedding model may not understand
- Query is very short (1–2 tokens) — short queries have noisy embeddings

**Vector search dominates when:**
- Query is conceptual or paraphrased ("how do I cancel my subscription")
- User doesn't know the exact terminology the document uses
- Cross-lingual retrieval (query in English, documents in French)
- Query is long and descriptive

For most production queries, both signals contribute. RRF handles the blending automatically — you don't need to manually detect which query type you have.

## Reranking After Fusion

After RRF, take the top-20 fused results and pass them through a cross-encoder reranker. The cross-encoder sees the full query+document pair and produces a calibrated relevance score. This is the most accurate step but also the most expensive — that's why you run it only on the top-20, not the full corpus.

Cross-encoder models: `cross-encoder/ms-marco-MiniLM-L-6-v2` (fast), `bge-reranker-large` (accurate). Run locally with Hugging Face transformers.

Select top 3–5 after reranking for generation.

## Key Rules

- Always combine BM25 + vector; use pure vector only if your queries are exclusively conceptual with no exact-term lookups.
- Use RRF with k=60 for merging; don't try to normalize and add BM25/cosine scores directly.
- Run a cross-encoder reranker on the top-20 fused results before passing to the generator.
- Tokenize BM25 index and queries identically; mismatch kills recall for keyword search.
- Log which signal dominated (rank in BM25 list vs vector list) for query analysis and system tuning.
