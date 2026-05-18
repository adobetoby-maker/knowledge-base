# Agent Pattern: Batch Processing

## Relationship to Batch Orchestration

`agents--batch-orchestration.md` covers the orchestrator-worker model for spawning independent sub-agents. This file focuses on the agent-side mechanics: how to chunk input, bound concurrency, track progress, handle partial failures, and aggregate results. These concerns apply whether the "workers" are sub-agents, API calls, or function invocations.

## Chunking Large Inputs

Never pass an entire large dataset to a single agent call. Large inputs cause context overflow, slow responses, and make partial failures unrecoverable. Chunk instead:

```typescript
function chunk<T>(items: T[], size: number): T[][] {
  const chunks: T[][] = []
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size))
  }
  return chunks
}
```

Chunk size depends on the task. For LLM processing: 5-20 items per chunk, sized so the prompt + items + output fits comfortably within the context window with room to spare. Do not pack chunks to the limit — overflow errors mid-batch are expensive to recover from.

Label each chunk with its index and total count. The agent needs to know "chunk 3 of 12" to produce coherent partial results and to generate accurate progress reports.

## Bounded Concurrency

Uncapped parallelism burns through rate limits and creates unpredictable load. Use a semaphore:

```typescript
async function processBatch<T, R>(
  items: T[],
  process: (item: T) => Promise<R>,
  concurrency: number = 5
): Promise<PromiseSettledResult<R>[]> {
  const semaphore = new Semaphore(concurrency)
  return Promise.allSettled(
    items.map(item => semaphore.run(() => process(item)))
  )
}
```

`Promise.allSettled` is intentional — it does not short-circuit on failure. Every item gets processed; failures are collected, not thrown. The right concurrency value is: (rate limit RPM / 60) × safe_fraction. For a 1000 RPM limit, concurrency of 10-15 is conservative enough to avoid hitting the limit under normal latency variance.

## Progress Tracking

Long batches need observable progress. Write state to durable storage at checkpoint intervals, not just in memory:

```typescript
interface BatchProgress {
  jobId: string
  total: number
  completed: number
  failed: number
  results: Record<string, BatchResult>
  startedAt: string
  updatedAt: string
}

async function checkpoint(progress: BatchProgress): Promise<void> {
  await kv.set(`batch:${progress.jobId}`, JSON.stringify(progress))
}
```

Checkpoint after every N completions (not every item — that is too expensive) or after every chunk. If the process is killed, resumption starts from the last checkpoint rather than from scratch.

## Partial Failure Handling

Batches will have failures. The question is whether a failure in item 47 should stop items 48-200. Almost always: no.

Collect failures with full context:

```typescript
interface BatchFailure {
  itemId: string
  input: unknown
  error: string
  attempt: number
}
```

After the batch completes, the result set has three partitions: succeeded, failed, skipped (items that were not reached due to a hard stop). Report all three. A batch that silently drops failures is worse than one that fails loudly.

Retry logic belongs inside the worker, not the orchestrator. Each item gets N attempts with backoff before it is moved to the failed partition. Do not retry at the batch level — that re-processes successes.

## Result Aggregation

Aggregation strategy depends on the task:

- **Structured data** (records, JSONs): merge into a single array or map, keyed by item ID
- **Text generation** (summaries, analyses): keep results in a list indexed by input item; do not concatenate — concatenated text loses provenance
- **Validation results**: group into pass/fail/error buckets with counts

Always preserve item identity in the output. A result with no link back to its input is useless for debugging and reprocessing.

## Key Rules

- Chunk inputs; never process an entire large dataset in one call
- Use `Promise.allSettled`, not `Promise.all` — batches must not abort on a single failure
- Cap concurrency at a fraction of the rate limit, not at an arbitrary large number
- Write progress to durable storage so jobs are resumable after interruption
- Retry belongs inside the worker with per-item backoff; batch-level retry re-processes successes
- Every output item must carry its input ID; anonymous results cannot be debugged
- Report succeeded, failed, and skipped counts separately in the final summary
