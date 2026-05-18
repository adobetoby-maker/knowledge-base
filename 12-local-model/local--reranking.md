# Reranking Search Results with a Local Model

## Why Reranking Exists

First-stage retrieval (BM25 keyword search or bi-encoder vector search) optimizes for speed — it scans millions of documents to produce a candidate set. It does not optimize for relevance to the exact query. A bi-encoder embeds the query and each document independently and computes dot product — it never "sees" the query and document together. This produces good recall but imprecise ranking.

A cross-encoder reads the query and document jointly in a single forward pass, producing a relevance score that reflects their interaction. It is far more accurate, but too slow to run over millions of documents. The solution: run fast first-stage retrieval to get top-K candidates (K=20–100), then run the cross-encoder reranker over that small set.

## Cross-Encoder vs Bi-Encoder

| | Bi-Encoder | Cross-Encoder |
|---|---|---|
| Input | Query OR document separately | Query AND document together |
| Speed | Fast (pre-compute doc embeddings) | Slow (must run per (query, doc) pair) |
| Accuracy | Moderate | High |
| Scale | Millions of docs | Tens to hundreds of docs |
| Use | First-stage retrieval | Reranking |

For local deployment, `cross-encoder/ms-marco-MiniLM-L-6-v2` (sentence-transformers) is a strong reranker that runs on CPU in <100ms for 20 candidates.

```python
from sentence_transformers import CrossEncoder

reranker = CrossEncoder("cross-encoder/ms-marco-MiniLM-L-6-v2")

def rerank(query: str, candidates: list[str], top_n: int = 5) -> list[str]:
    pairs = [(query, doc) for doc in candidates]
    scores = reranker.predict(pairs)
    ranked = sorted(zip(scores, candidates), key=lambda x: x[0], reverse=True)
    return [doc for _, doc in ranked[:top_n]]
```

## Score Normalization

Cross-encoder raw scores are not bounded — they can be negative or large positive values depending on the model. Do not compare raw scores across different queries or different models.

Normalize to [0, 1] within each query's candidate set using min-max normalization:

```python
def normalize_scores(scores: list[float]) -> list[float]:
    min_s, max_s = min(scores), max(scores)
    if max_s == min_s:
        return [1.0] * len(scores)
    return [(s - min_s) / (max_s - min_s) for s in scores]
```

This allows a relevance threshold to be applied consistently: if the top result normalizes to < 0.5, the system can conclude the query has no good match in the corpus.

## How Many Candidates to Rerank (K)

Retrieve K=20 for most tasks. Going higher (K=50–100) adds latency without meaningfully improving the final top-5 result. The cross-encoder's job is to promote the truly relevant item that first-stage retrieval found but ranked low — if it's not in the top 20, it was likely missed by first-stage retrieval entirely (a recall problem, not a ranking problem).

For domains with very high answer density (e.g., large codebases where many functions partially match a query), increase K to 50.

## When Reranking Adds Value

Use reranking when:
- User queries are conversational/verbose and exact-match BM25 undersells semantic matches
- The corpus is dense and many documents partially match (reranking separates near-matches from good matches)
- Quality matters more than latency (e.g., document search, not autocomplete)

Skip reranking when:
- Queries are short keyword searches where BM25 already returns the right document in position 1
- Latency budget is under 50ms (reranking adds 50–200ms on CPU for K=20)
- The corpus is small enough (<500 docs) that first-stage precision is already high

## Latency Budget

Cross-encoder reranking on CPU: ~50–150ms for K=20 with a MiniLM model. On GPU: ~5–20ms.

If this is unacceptable, consider: returning first-stage results immediately while reranking asynchronously for a second-pass update, or using a lighter reranker (fewer layers).

## Key Rules

- Always pair reranking with a fast first-stage retrieval; never rerank the full corpus
- Use K=20 candidates by default; increase to 50 only for high-density corpora
- Normalize cross-encoder scores within each query's candidate set before thresholding
- Use `cross-encoder/ms-marco-MiniLM-L-6-v2` as a solid local CPU-friendly default
- Skip reranking when latency budget < 50ms or first-stage precision is already high
- Reranking solves ranking problems, not recall problems — if the answer isn't in K candidates, fix retrieval
