# Skill: Vector Database Setup

## Overview
Vector databases power semantic search, recommendation systems, and RAG pipelines by finding items with similar meaning rather than exact text matches. The right choice depends on scale: pgvector on existing Postgres handles millions of vectors with no additional infrastructure. Dedicated vector databases (Pinecone, Weaviate, Qdrant) add operational overhead but handle hundreds of millions of vectors with better latency and filtering at scale.

## When to Use What

| Scale | Choice | Why |
|---|---|---|
| < 1M vectors | pgvector (Postgres) | Already have Postgres, no extra infra, SQL joins |
| 1M – 10M | pgvector with HNSW index | HNSW performs well at this scale |
| > 10M | Pinecone / Weaviate / Qdrant | Purpose-built, managed, horizontal scaling |
| Need metadata filters + vector | Qdrant | Best combined vector + filter performance |

## pgvector Setup

```sql
-- Enable extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Schema with embedding column
CREATE TABLE documents (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content     TEXT NOT NULL,
  metadata    JSONB DEFAULT '{}',
  embedding   vector(1536),  -- dimension matches your model (OpenAI: 1536, all-MiniLM: 384)
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- IVFFlat index for ANN search (approximate nearest neighbor)
-- lists = sqrt(num_rows) is a good starting point
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Or HNSW for better recall at higher memory cost (Postgres 16+ / pgvector 0.5+)
CREATE INDEX ON documents USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);
```

HNSW has better query time but slower index build. IVFFlat builds fast but requires `SET ivfflat.probes` tuning.

## Inserting Embeddings

```ts
import OpenAI from 'openai'
import { createClient } from '@supabase/supabase-js'

const openai = new OpenAI()
const supabase = createClient(url, serviceKey)

async function embedAndStore(content: string, metadata: object) {
  // Generate embedding
  const response = await openai.embeddings.create({
    model: 'text-embedding-3-small',  // 1536 dims, cheaper than ada-002
    input: content,
  })
  const embedding = response.data[0].embedding

  // Store
  const { error } = await supabase.from('documents').insert({
    content,
    metadata,
    embedding: JSON.stringify(embedding),  // Supabase serializes vector type
  })

  if (error) throw error
}
```

## Similarity Search Query

```sql
-- Find 10 most similar documents to a query embedding
-- <=> = cosine distance (0 = identical, 2 = opposite)
-- <-> = Euclidean distance
-- <#> = negative inner product (use for normalized vectors)

SELECT
  id,
  content,
  metadata,
  1 - (embedding <=> $1) AS similarity
FROM documents
ORDER BY embedding <=> $1
LIMIT 10;
```

In TypeScript via Supabase RPC:

```ts
async function semanticSearch(query: string, limit = 10) {
  const embedding = await getEmbedding(query)

  const { data, error } = await supabase.rpc('match_documents', {
    query_embedding: embedding,
    match_threshold: 0.7,  // minimum similarity score
    match_count: limit,
  })

  return data
}
```

```sql
-- The RPC function
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding vector(1536),
  match_threshold float,
  match_count int
)
RETURNS TABLE (id uuid, content text, metadata jsonb, similarity float)
LANGUAGE sql STABLE
AS $$
  SELECT id, content, metadata, 1 - (embedding <=> query_embedding) AS similarity
  FROM documents
  WHERE 1 - (embedding <=> query_embedding) > match_threshold
  ORDER BY embedding <=> query_embedding
  LIMIT match_count;
$$;
```

## Re-indexing Strategy

IVFFlat performance degrades when the data distribution changes significantly. Rebuild when:
- Adding > 10% new data since last index
- Similarity scores seem unexpectedly low
- After major content updates

```sql
REINDEX INDEX CONCURRENTLY documents_embedding_idx;
```

HNSW degrades less but still benefits from periodic rebuilds on large inserts.

## Key Rules
- Dimension must match the model — store which model generated embeddings in metadata
- Re-embed everything when switching models — embeddings from different models are incompatible
- IVFFlat: set `ivfflat.probes` higher (10–50) for better recall at cost of speed
- Store original content alongside embedding — you'll need it for context in RAG
- Never compare embeddings from different models — results are meaningless
- For hybrid search: combine vector similarity with full-text (`tsvector`) using RRF (reciprocal rank fusion)
- Batch embed large datasets — OpenAI allows up to 2048 inputs per API call
