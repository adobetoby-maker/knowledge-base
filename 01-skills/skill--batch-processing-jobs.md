# Skill: Batch Processing Job Patterns

## Overview
Batch jobs that process thousands of records fail in specific, predictable ways: they run out of memory loading everything at once, crash midway with no recovery path, and fail one bad record taking down the entire run. The patterns below make batch jobs resumable on restart, memory-efficient at any scale, and fault-isolated so one bad row doesn't abort the rest.

## Implementation

### 1. Chunked processing with checkpoint
```ts
// jobs/sync-users.ts
const CHUNK_SIZE = 1000;

interface JobProgress {
  jobId: string;
  lastProcessedId: string | null;  // cursor for resuming
  processedCount: number;
  failedCount: number;
  startedAt: Date;
}

async function runSyncJob(jobId: string) {
  // Load or initialize checkpoint
  let progress = await db.jobProgress.findUnique({ where: { jobId } })
    ?? await db.jobProgress.create({
      data: { jobId, lastProcessedId: null, processedCount: 0, failedCount: 0, startedAt: new Date() }
    });

  console.log(`Starting job ${jobId} from cursor: ${progress.lastProcessedId ?? 'beginning'}`);

  let cursor = progress.lastProcessedId;
  let totalProcessed = progress.processedCount;
  let totalFailed = progress.failedCount;

  while (true) {
    // Fetch next chunk using cursor-based pagination (not offset — offset skips on inserts)
    const chunk = await db.users.findMany({
      take: CHUNK_SIZE,
      ...(cursor ? { skip: 1, cursor: { id: cursor } } : {}),
      orderBy: { id: 'asc' },  // stable sort required for cursor to work
    });

    if (chunk.length === 0) break;  // done

    // Process chunk — error isolation: one failure doesn't abort the chunk
    const results = await processChunk(chunk);
    totalProcessed += results.succeeded;
    totalFailed += results.failed;
    cursor = chunk[chunk.length - 1].id;

    // Checkpoint after each successful chunk — restart resumes from here
    await db.jobProgress.update({
      where: { jobId },
      data: { lastProcessedId: cursor, processedCount: totalProcessed, failedCount: totalFailed },
    });

    console.log(`Chunk done: ${totalProcessed} processed, ${totalFailed} failed`);
  }

  // Final report
  await db.jobProgress.update({
    where: { jobId },
    data: { completedAt: new Date(), status: 'complete' },
  });

  console.log(`Job ${jobId} complete: ${totalProcessed} processed, ${totalFailed} failed`);
}
```

### 2. Error-isolated chunk processing
```ts
interface ChunkResult {
  succeeded: number;
  failed: number;
}

async function processChunk(records: User[]): Promise<ChunkResult> {
  let succeeded = 0;
  let failed = 0;

  // Process each record independently — one failure does not stop others
  await Promise.allSettled(
    records.map(async (record) => {
      try {
        await processRecord(record);
        succeeded++;
      } catch (err) {
        failed++;
        // Log failed row with enough context to debug + retry manually
        await db.jobErrors.create({
          data: {
            recordId: record.id,
            error: err instanceof Error ? err.message : String(err),
            recordSnapshot: record,  // preserve state at time of failure
          },
        });
      }
    })
  );

  return { succeeded, failed };
}
```

### 3. Idempotency on each chunk (skip already-processed)
```ts
async function processRecord(user: User): Promise<void> {
  // Check if already processed — idempotent even if job re-runs same chunk
  const existing = await db.syncedUser.findUnique({ where: { userId: user.id } });
  if (existing) {
    console.debug(`Skipping already-synced user ${user.id}`);
    return;
  }

  // Do the actual work
  await externalService.createUser({
    id: user.id,
    email: user.email,
    name: user.name,
  });

  // Mark as processed
  await db.syncedUser.create({ data: { userId: user.id, syncedAt: new Date() } });
}
```

### 4. Summary report on completion
```ts
async function generateReport(jobId: string): Promise<void> {
  const progress = await db.jobProgress.findUniqueOrThrow({ where: { jobId } });
  const errors = await db.jobErrors.findMany({ where: { jobId } });
  const duration = (progress.completedAt!.getTime() - progress.startedAt.getTime()) / 1000;

  const report = {
    jobId,
    duration: `${duration}s`,
    processed: progress.processedCount,
    failed: progress.failedCount,
    successRate: `${((progress.processedCount / (progress.processedCount + progress.failedCount)) * 100).toFixed(1)}%`,
    errors: errors.slice(0, 10).map(e => ({ id: e.recordId, error: e.error })),
    hasMoreErrors: errors.length > 10,
  };

  // Send to Slack, email, or logging service
  await notify(report);
}
```

### 5. Memory-efficient streaming (for very large datasets)
```ts
// Use cursor streaming instead of findMany for millions of rows
async function* streamUsers(cursor?: string): AsyncGenerator<User> {
  let current = cursor;
  while (true) {
    const batch = await db.users.findMany({
      take: CHUNK_SIZE,
      ...(current ? { skip: 1, cursor: { id: current } } : {}),
      orderBy: { id: 'asc' },
    });
    if (!batch.length) return;
    yield* batch;
    current = batch[batch.length - 1].id;
  }
}
```

## Key Rules
- **Checkpoint after every chunk** — if the job crashes at chunk 50 of 200, it resumes from chunk 50, not chunk 1.
- **Use cursor pagination, not offset** — `OFFSET 1000` skips rows inserted during the run; cursor-based is stable.
- **Isolate errors per record, not per chunk** — `Promise.allSettled` lets good records succeed when neighbors fail.
- Log failed records with their full state snapshot — you need enough data to retry or debug without re-running the whole job.
- **Idempotency on each record** — re-running the job (or reprocessing a chunk) must not double-process records.
- Process chunks with `Promise.allSettled`, not `Promise.all` — `Promise.all` fails the whole chunk on first error.
- Alert on high failure rates (> 5%) — individual failures are expected; widespread failures indicate a systematic bug.
