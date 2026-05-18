# Building a Vector Index with Local Embeddings

A fully local vector search pipeline — embeddings generated on your hardware, stored in your database — means zero latency for embedding API calls, no per-token cost, and no data leaving your infrastructure. The tradeoff is embedding quality: local embedding models produce shorter vectors and cover fewer semantic nuances than large hosted models. For most retrieval tasks over domain-specific text, this is an acceptable tradeoff.

## Embedding Model: nomic-embed-text

`nomic-embed-text` (via Ollama) is the best general-purpose local embedding model for English text. It produces 768-dimensional vectors, outperforms many older OpenAI `ada-002`-class embeddings on benchmark retrieval tasks, and runs fast on CPU.

```bash
ollama pull nomic-embed-text
```

Generate embeddings:
```python
import ollama

def embed(text: str) -> list[float]:
    response = ollama.embeddings(model="nomic-embed-text", prompt=text)
    return response["embedding"]
```

For non-English text, evaluate before committing — `nomic-embed-text` is primarily English-optimized. For multilingual needs, `mxbai-embed-large` or a sentence-transformers model run via llama.cpp may perform better.

## pgvector as Vector Store

`pgvector` extends PostgreSQL with a native vector column type and ANN index. It's the right choice when you already use Postgres (Supabase includes it). Avoid running a separate vector database (Pinecone, Weaviate, Qdrant) if your existing Postgres can handle the load — operational complexity isn't worth it for most workloads under 1M vectors.

Setup:
```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content TEXT,
  metadata JSONB,
  embedding vector(768)  -- match nomic-embed-text dimensions
);

-- HNSW index for fast ANN search
CREATE INDEX ON documents USING hnsw (embedding vector_cosine_ops);
```

HNSW (`hnsw`) gives faster query performance than IVFFlat for most workloads. Use IVFFlat only if you need to control memory usage precisely.

## Cosine Similarity Search

Cosine similarity is the right distance metric for text embeddings (vectors of varying magnitude, care about direction not length):

```sql
SELECT id, content, 1 - (embedding <=> $1::vector) AS similarity
FROM documents
ORDER BY embedding <=> $1::vector
LIMIT 10;
```

The `<=>` operator is pgvector's cosine distance (1 - similarity). A similarity score above 0.85 is typically high relevance; below 0.7 is low relevance. Calibrate thresholds on your specific corpus and query distribution — don't use universal cutoffs.

## Index Rebuilding When the Embedding Model Changes

This is the most common operational mistake: upgrading the embedding model without rebuilding the index. Different models produce vectors in different spaces. A `nomic-embed-text` embedding searched against an index of `mxbai-embed-large` embeddings returns garbage — the cosine distance is meaningless across model families.

When changing embedding models:

1. Generate new embeddings for all documents with the new model
2. Write them to a new column (`embedding_v2`) rather than overwriting
3. Rebuild the index on the new column
4. Test search quality on a validation set before cutover
5. Drop the old column and rename after validation passes

This is a migration, not an in-place update. Treat it as such: version your embeddings, keep old embeddings until the new ones are validated, and never overwrite without a rollback path.

Also reindex when: chunking strategy changes (different chunk sizes produce different vectors for the same document), or when you add significant new content to the corpus (the HNSW index benefits from periodic rebuilds at high insertion volumes).

## Key Rules

- Use `nomic-embed-text` via Ollama for English text; evaluate alternatives for multilingual
- Store embeddings in pgvector if you already use Postgres — avoid a separate vector DB unless at scale
- Use HNSW index with `vector_cosine_ops` for fast ANN search
- Never mix embeddings from different models in the same index
- Treat embedding model upgrades as migrations: write to a new column, validate, then cut over
- Calibrate similarity thresholds on your corpus — don't use generic cutoff values
- Reindex after chunking strategy changes, not just model changes
