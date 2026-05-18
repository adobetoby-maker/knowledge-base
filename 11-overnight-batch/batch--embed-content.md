# Nightly Content Embedding for RAG

Retrieval-Augmented Generation (RAG) requires that your content library be embedded — converted to vectors — before it can be searched semantically. The nightly embedding batch keeps vectors in sync with content that was created or updated since the last run.

## Only Process New and Updated Content

Embedding everything from scratch nightly is wasteful and expensive. Use a `last_embedded_at` timestamp on each content record to scope the job:

```sql
SELECT id, content, updated_at
FROM articles
WHERE updated_at > :last_run_at
   OR last_embedded_at IS NULL
ORDER BY updated_at ASC;
```

Store `last_run_at` in a batch job metadata table, updated on successful completion. If the job fails midway, resume from the same `last_run_at` on the next run — partial re-embedding is safe because you upsert by record ID.

## Chunking Strategy

Embedding an entire document as one vector produces poor retrieval. Long documents contain multiple topics — a single vector averages them together and matches poorly for specific queries.

Chunk before embedding:
- **Target chunk size**: 256–512 tokens (roughly 200–400 words). Smaller chunks have higher precision; larger chunks provide more context per retrieved result.
- **Overlap**: 10–20% overlap between adjacent chunks. A sentence split across a chunk boundary won't be orphaned.
- **Semantic boundaries**: split on paragraph breaks first, then sentences, then by token count. Never split mid-sentence.
- **Metadata per chunk**: store `source_id`, `chunk_index`, `chunk_total`, `start_char`, source metadata (title, url, date). Retrieval returns chunks — you need to reconstruct the source record.

```ts
// Example chunk record
{
  id: 'article:42:chunk:3',
  source_id: 42,
  chunk_index: 3,
  content: "...",
  metadata: { title: "How brakes work", url: "/articles/brakes", date: "2025-01-15" }
}
```

## Batch Embedding via API

Embedding APIs charge per token. Batch requests are cheaper per token than individual requests and have higher throughput. Use the batch endpoint when available.

```ts
// OpenAI text-embedding-3-small batch
const response = await openai.embeddings.create({
  model: 'text-embedding-3-small',
  input: chunks.map(c => c.content), // array of up to 2048 inputs
});
```

Process in batches of 100–500 chunks per API call. Track cost per run in the batch metadata table — embedding cost should be near-zero for incremental runs and visible when large content imports happen.

## Upsert to Vector Store

Use upsert (insert or replace by ID) so re-runs are idempotent:

```ts
await vectorStore.upsert({
  vectors: chunks.map((chunk, i) => ({
    id: chunk.id,
    values: response.data[i].embedding,
    metadata: chunk.metadata,
  }))
});
```

After upserting, update `last_embedded_at` on the source record in your application DB. This is the source of truth for "has this been embedded."

## Re-Embedding When Model Changes

When you upgrade to a new embedding model, the old vectors are incompatible — cosine similarity between old and new model vectors is meaningless. You must re-embed everything.

Process for model migration:
1. Create a new index/namespace in the vector store
2. Run a full re-embedding job against the new model into the new index
3. Swap application queries to the new index
4. Delete the old index after a validation period

Don't mix vectors from different models in the same index. Track the embedding model version on each vector record so you know which vectors need re-processing.

## Key Rules

- Only embed new/updated content since last run; store `last_run_at` in job metadata
- Chunk documents before embedding; 256–512 tokens with 10–20% overlap
- Store chunk metadata (source_id, chunk_index, title, url) with each vector
- Batch API calls (100–500 chunks per request) to minimize cost and latency
- Upsert by chunk ID so runs are idempotent; update `last_embedded_at` on success
- Never mix vectors from different embedding models in the same index
- Re-embed all content into a new index when upgrading models; swap atomically
