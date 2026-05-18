# Skill: Vector Embedding Pipeline

## Overview
Vector embeddings enable semantic search — finding content by meaning rather than exact keywords. The tricky parts: chunking strategy determines result quality more than model choice, cosine similarity requires normalized vectors or the wrong results surface, and re-indexing on content updates must be incremental or it blocks writes.

## Implementation

### 1. Database setup with pgvector
```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE documents (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_id  uuid NOT NULL,        -- FK to your source record
  chunk_index int NOT NULL,         -- position within source document
  text        text NOT NULL,
  embedding   vector(1536),         -- OpenAI text-embedding-3-small dimension
  metadata    jsonb DEFAULT '{}',   -- title, url, type, etc. for filtering
  created_at  timestamptz DEFAULT now(),
  UNIQUE (content_id, chunk_index)
);

-- IVFFlat index — build after inserting > 10k rows for accuracy
-- lists = sqrt(row_count) is a good starting point
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
```

### 2. Chunking strategy (quality bottleneck)
```ts
function chunkText(text: string, maxTokens = 512, overlapTokens = 50): string[] {
  // Rough token estimate: 1 token ≈ 4 chars for English
  const maxChars = maxTokens * 4;
  const overlapChars = overlapTokens * 4;
  
  const chunks: string[] = [];
  let start = 0;
  
  while (start < text.length) {
    let end = start + maxChars;
    
    // Don't cut mid-sentence — find nearest sentence boundary
    if (end < text.length) {
      const boundary = text.lastIndexOf('. ', end);
      if (boundary > start + maxChars * 0.5) end = boundary + 2;
    }
    
    chunks.push(text.slice(start, end).trim());
    start = end - overlapChars;  // overlap preserves context across chunk boundaries
  }
  
  return chunks.filter(c => c.length > 50);  // skip tiny fragments
}
```

### 3. Generate embeddings
```ts
import OpenAI from 'openai';
const openai = new OpenAI();

async function embedChunks(chunks: string[]): Promise<number[][]> {
  // Batch up to 2048 inputs per API call
  const BATCH_SIZE = 100;
  const embeddings: number[][] = [];
  
  for (let i = 0; i < chunks.length; i += BATCH_SIZE) {
    const batch = chunks.slice(i, i + BATCH_SIZE);
    const res = await openai.embeddings.create({
      model: 'text-embedding-3-small',  // 1536 dims, cheap, fast
      input: batch,
    });
    embeddings.push(...res.data.map(d => d.embedding));
  }
  
  return embeddings;
}
```

### 4. Index a document
```ts
async function indexDocument(contentId: string, text: string, metadata: object) {
  const chunks = chunkText(text);
  const embeddings = await embedChunks(chunks);
  
  // Delete old chunks for this content (re-index case)
  await db.execute(sql`DELETE FROM documents WHERE content_id = ${contentId}`);
  
  // Insert new chunks
  await db.insert(documents).values(
    chunks.map((text, i) => ({
      contentId,
      chunkIndex: i,
      text,
      embedding: embeddings[i],  // pgvector driver accepts number[]
      metadata,
    }))
  );
}
```

### 5. Semantic search
```ts
async function search(query: string, topK = 10, filter?: { type: string }) {
  const [queryEmbedding] = await embedChunks([query]);
  
  // Cosine similarity: 1 - cosine distance (<=> operator)
  const results = await db.execute(sql`
    SELECT
      id,
      content_id,
      text,
      metadata,
      1 - (embedding <=> ${queryEmbedding}::vector) AS similarity
    FROM documents
    ${filter ? sql`WHERE metadata->>'type' = ${filter.type}` : sql``}
    ORDER BY embedding <=> ${queryEmbedding}::vector
    LIMIT ${topK}
  `);
  
  // Filter by similarity threshold — below 0.7 is usually noise
  return results.rows.filter(r => r.similarity > 0.7);
}
```

### 6. Re-index on content update (queue-based)
```ts
// Trigger re-index via job queue — don't block the write request
async function onDocumentUpdated(contentId: string) {
  await queue.add('reindex', { contentId }, { delay: 0 });
}

// Worker
queue.process('reindex', async (job) => {
  const doc = await db.content.findUnique({ where: { id: job.data.contentId } });
  if (!doc) return;  // deleted — old chunks cleaned up by cascade
  await indexDocument(doc.id, doc.body, { type: doc.type, title: doc.title });
});
```

## Key Rules
- **Chunk at ~512 tokens with overlap** — chunks too large lose specificity, too small lose context. Overlap (50 tokens) prevents answers being cut at chunk boundaries.
- Build the IVFFlat index only after inserting meaningful data — index on empty table produces poor partitioning.
- The `<=>` operator in pgvector is cosine distance (lower = more similar). To get similarity score, use `1 - (embedding <=> ...)`.
- Always delete old chunks before re-indexing — `UNIQUE (content_id, chunk_index)` prevents duplicates but chunk count may decrease on edits.
- Embed the search query with the same model used to embed documents — mixing models produces garbage results.
- For production, HNSW index is faster at query time than IVFFlat; requires pgvector 0.5+.
- Store metadata in the `documents` table, not a join — avoids expensive joins on every search.
