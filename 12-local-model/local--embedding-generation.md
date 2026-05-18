# Local Models: Embedding Generation

## Overview

Embeddings are numeric vectors that represent semantic meaning. Two texts with similar embeddings are semantically similar. Use local embedding models for: semantic search, clustering documents, deduplication, and RAG (Retrieval Augmented Generation) without sending data to external APIs.

## Ollama Embeddings API

```ts
async function getEmbedding(text: string, model = 'nomic-embed-text'): Promise<number[]> {
  const response = await fetch('http://localhost:11434/api/embeddings', {
    method: 'POST',
    body: JSON.stringify({ model, prompt: text }),
  })
  const data = await response.json()
  return data.embedding  // Array of 768 or 1536 floats
}

// Batch embeddings
async function getEmbeddingsBatch(texts: string[]): Promise<number[][]> {
  return Promise.all(texts.map(t => getEmbedding(t)))
}
```

## Recommended Models

| Model | Dimensions | Size | Notes |
|---|---|---|---|
| `nomic-embed-text` | 768 | 274MB | Good general purpose |
| `mxbai-embed-large` | 1024 | 669MB | Higher quality |
| `all-minilm` | 384 | 45MB | Fast, small, decent |
| `bge-m3` | 1024 | 1.2GB | Best multilingual |

```bash
# Pull the model first
ollama pull nomic-embed-text
```

## Cosine Similarity

Measure similarity between two embeddings:

```ts
function cosineSimilarity(a: number[], b: number[]): number {
  const dotProduct = a.reduce((sum, ai, i) => sum + ai * b[i], 0)
  const magnitudeA = Math.sqrt(a.reduce((sum, ai) => sum + ai * ai, 0))
  const magnitudeB = Math.sqrt(b.reduce((sum, bi) => sum + bi * bi, 0))
  return dotProduct / (magnitudeA * magnitudeB)
}

// 1.0 = identical, 0.0 = unrelated, -1.0 = opposite
const similarity = cosineSimilarity(embed1, embed2)
console.log(similarity > 0.85 ? 'Very similar' : 'Different')
```

## Semantic Search Pipeline

```ts
interface Document {
  id: string
  text: string
  embedding?: number[]
}

// Index: compute and store embeddings
async function indexDocuments(docs: Document[]): Promise<Document[]> {
  return Promise.all(
    docs.map(async doc => ({
      ...doc,
      embedding: await getEmbedding(doc.text),
    }))
  )
}

// Search: find most similar documents
async function semanticSearch(
  query: string,
  documents: Required<Document>[],
  topK = 5,
): Promise<Array<Document & { score: number }>> {
  const queryEmbedding = await getEmbedding(query)

  return documents
    .map(doc => ({
      ...doc,
      score: cosineSimilarity(queryEmbedding, doc.embedding),
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, topK)
    .filter(d => d.score > 0.5)  // Relevance threshold
}
```

## Storing in Postgres with pgvector

For production-scale semantic search:

```sql
CREATE EXTENSION vector;

CREATE TABLE documents (
  id      UUID PRIMARY KEY,
  content TEXT NOT NULL,
  embedding vector(768)  -- Match model dimensions
);

CREATE INDEX documents_embedding_idx ON documents
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);
```

```ts
// Insert with embedding
await db.execute(sql`
  INSERT INTO documents (id, content, embedding)
  VALUES (${id}, ${content}, ${JSON.stringify(embedding)}::vector)
`)

// Semantic search via SQL
const results = await db.execute(sql`
  SELECT id, content, 1 - (embedding <=> ${JSON.stringify(queryEmbedding)}::vector) AS similarity
  FROM documents
  WHERE 1 - (embedding <=> ${JSON.stringify(queryEmbedding)}::vector) > 0.5
  ORDER BY embedding <=> ${JSON.stringify(queryEmbedding)}::vector
  LIMIT 10
`)
```

## Chunking for Long Documents

Embedding models have token limits (typically 512-8192 tokens). Split long documents:

```ts
function chunkForEmbedding(text: string, maxChars = 1000, overlap = 100): string[] {
  const chunks: string[] = []
  let start = 0
  while (start < text.length) {
    chunks.push(text.slice(start, start + maxChars))
    start += maxChars - overlap
  }
  return chunks
}

// Embed per chunk, store with document reference
async function indexLongDocument(doc: { id: string; text: string }) {
  const chunks = chunkForEmbedding(doc.text)
  await Promise.all(
    chunks.map(async (chunk, i) => {
      const embedding = await getEmbedding(chunk)
      await storeChunk({ docId: doc.id, chunkIndex: i, chunk, embedding })
    })
  )
}
```

## Key Rules

- Embed the query and documents with the same model — mixing models produces meaningless comparisons.
- Similarity threshold 0.75-0.85 is typical for "same topic." Lower values return more results but with more noise.
- Store embeddings in Postgres with `pgvector` for production scale — in-memory similarity on 100K docs is still fast, but degrades.
- Overlap chunks by 10-15% to preserve context at boundaries.
- Batch embedding generation: sequential is fine for offline indexing; use `Promise.all` with concurrency limiting for real-time.
