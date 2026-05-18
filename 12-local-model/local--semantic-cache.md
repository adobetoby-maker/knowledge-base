# Semantic Caching for LLM Responses

## Why Semantic Cache, Not Exact Cache

An exact-match cache (keyed on raw prompt string) has near-zero hit rate for LLM queries because users rephrase the same question differently: "summarize this document", "give me a summary", "what does this document say", "tldr". These are semantically identical but string-different. Semantic caching embeds the query and matches on meaning, not characters.

At scale, semantic caching can reduce LLM inference costs by 20–60% for tasks with a high rate of semantically similar queries (customer support, FAQ answering, document Q&A on a fixed corpus).

## The Architecture

```
query → embed(query) → vector search in cache store
        if similarity > threshold → return cached response
        else → call LLM → store (embedding, response, TTL) → return response
```

The cache store must support approximate nearest-neighbor search: Redis with the VSS module, Qdrant, Weaviate, or pgvector. Do not use a flat list with cosine comparison — it does not scale past a few thousand entries.

## Similarity Threshold: 0.95

Use cosine similarity ≥ 0.95 as the default cache hit threshold. Below 0.95, semantically similar but meaningfully different queries start matching — "what is the refund policy" and "what is the cancellation policy" may score 0.91. Above 0.95, you're matching genuine paraphrases.

Calibrate the threshold against your specific domain and embedding model. Some domains (legal, medical) require higher thresholds (0.97–0.98) because small wording differences carry large meaning differences.

```python
def check_cache(query: str, threshold: float = 0.95):
    embedding = embed(query)
    results = vector_store.search(embedding, top_k=1)
    if results and results[0].score >= threshold:
        return results[0].cached_response
    return None
```

## TTL for Cache Freshness

Cached responses go stale when the underlying information changes. Set TTL based on how frequently the source data changes:

- Static knowledge base, documentation: 7–30 days
- Product information, pricing: 1–24 hours
- News, current events: 5–60 minutes
- Personalized or session-specific queries: do not cache (see below)

Implement TTL at the cache store level, not in application code. If the underlying data changes before the TTL expires, invalidate affected cache entries explicitly.

## When NOT to Use Semantic Cache

Do not cache responses for:
- **Personalized queries** — "What are my recent orders?" The answer differs per user. Keying by (user_id + embedding) defeats the purpose; other users won't hit the cache.
- **Queries with dynamic context** — when the system prompt includes a timestamp, current balance, or live data, the same question has a different correct answer at different times.
- **Generation tasks** — writing tasks where variation is valuable (marketing copy, email drafts). Returning the same text repeatedly is worse than generating fresh output.
- **Low-volume, high-diversity corpora** — if queries are unique by nature, building and querying the cache costs more than it saves.

The test: if two different users asking the same question should get the same answer, semantic caching applies. If they should get different answers, it doesn't.

## Storing Entries

Each cache entry needs:
```json
{
  "embedding": [...],
  "original_query": "...",
  "response": "...",
  "created_at": "...",
  "ttl_seconds": 86400,
  "metadata": { "model": "...", "prompt_version": "1.2" }
}
```

Store `prompt_version` in metadata. When the system prompt changes (e.g., a persona update), stale cache entries from the old prompt version will return wrong-persona responses. Invalidate by prompt version, not just by TTL.

## Key Rules

- Use cosine similarity ≥ 0.95 as the hit threshold; calibrate higher for precision domains
- Embed at query time using the same model used during cache population
- Set TTL based on source data volatility; invalidate explicitly when data changes
- Never cache personalized, session-specific, or live-data-dependent queries
- Store prompt_version with every entry; invalidate on prompt changes
- Use a vector store with ANN search; never flat-list cosine comparison at scale
