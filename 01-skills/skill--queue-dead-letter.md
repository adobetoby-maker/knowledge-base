# Skill: Dead Letter Queue (DLQ) Handling

## Overview
A dead letter queue (DLQ) is a holding area for messages that have failed processing N times. Without a DLQ, failed messages either block the queue indefinitely or are silently dropped — both are bad. With a DLQ, failed messages are preserved for inspection, the main queue keeps flowing, and engineers can replay individual messages after fixing the underlying bug. Never auto-requeue DLQ messages — they failed for a reason.

## DLQ Architecture

```
Main Queue → Consumer → [fails] → retry 1 → [fails] → retry 2 → [fails] → DLQ
                                                                              ↓
                                                                    DLQ Consumer (inspection only)
                                                                              ↓
                                                                    Alert: DLQ non-empty
                                                                              ↓
                                                           Manual replay after fix
```

## BullMQ Implementation

```ts
import { Queue, Worker, QueueEvents } from 'bullmq'
import { Redis } from 'ioredis'

const connection = new Redis(process.env.REDIS_URL!)

// Main queue
export const emailQueue = new Queue('emails', {
  connection,
  defaultJobOptions: {
    attempts: 3,             // retry 3 times total
    backoff: {
      type: 'exponential',
      delay: 1000,           // 1s, 2s, 4s
    },
    removeOnComplete: { count: 100 },
    removeOnFail: false,     // keep failed jobs for inspection
  },
})

// Worker
const worker = new Worker('emails', async (job) => {
  await sendEmail(job.data)
}, {
  connection,
  limiter: { max: 10, duration: 1000 },  // rate limit
})

// After max retries exhausted — move to DLQ
worker.on('failed', async (job, err) => {
  if (job && job.attemptsMade >= (job.opts.attempts ?? 3)) {
    // Move to DLQ queue
    await dlqQueue.add('failed-email', {
      originalJob: job.data,
      error: err.message,
      failedAt: new Date().toISOString(),
      attempts: job.attemptsMade,
    })

    // Alert
    await notifyOpsChannel(`DLQ: email job ${job.id} failed after ${job.attemptsMade} attempts: ${err.message}`)
  }
})
```

## DLQ Consumer (Inspection Only)

The DLQ consumer does not retry automatically — it logs and alerts:

```ts
const dlqWorker = new Worker('dlq', async (job) => {
  // Log for analysis
  console.error(JSON.stringify({
    event: 'dlq_message',
    queue: job.data.originalQueue,
    jobData: job.data.originalJob,
    error: job.data.error,
    failedAt: job.data.failedAt,
  }))

  // Store in DB for dashboard inspection
  await db.dlqMessages.create({
    data: {
      queue: job.data.originalQueue,
      payload: job.data.originalJob,
      error: job.data.error,
      failed_at: new Date(job.data.failedAt),
      status: 'pending_review',
    },
  })
}, { connection })
```

## Alert When DLQ is Non-Empty

```ts
// Check DLQ depth on an interval
async function checkDlqDepth() {
  const waiting = await dlqQueue.getWaitingCount()
  if (waiting > 0) {
    await sendAlert({
      severity: 'warning',
      message: `DLQ has ${waiting} unprocessed messages`,
      link: 'https://internal/dlq-dashboard',
    })
  }
}

// Run every 5 minutes
setInterval(checkDlqDepth, 5 * 60 * 1000)
```

## Manual Replay After Fix

```ts
// app/api/admin/dlq/replay/route.ts
export async function POST(req: Request) {
  const { messageId } = await req.json()

  const dlqMessage = await db.dlqMessages.findUnique({ where: { id: messageId } })
  if (!dlqMessage) return Response.json({ error: 'Not found' }, { status: 404 })

  // Re-enqueue to original queue
  await emailQueue.add('retry', dlqMessage.payload, {
    attempts: 3,  // fresh retry counter
  })

  await db.dlqMessages.update({
    where: { id: messageId },
    data: { status: 'replayed', replayed_at: new Date() },
  })

  return Response.json({ ok: true })
}
```

Only replay after deploying the fix. Replaying before fixing just re-fails.

## DLQ Retention Policy

```ts
// DLQ queue with retention limit
const dlqQueue = new Queue('dlq', {
  connection,
  defaultJobOptions: {
    removeOnComplete: false,
    removeOnFail: { age: 7 * 24 * 3600 },  // keep failed DLQ jobs 7 days
  },
})
```

7 days is enough to investigate and replay. After that, messages are evidence of a bug that was either fixed (replayed) or accepted (dropped).

## Key Rules
- Never auto-requeue DLQ messages — they'll just fail again and loop forever
- Alert when DLQ becomes non-empty — a non-empty DLQ is always a signal requiring investigation
- Set DLQ retention to 7 days — long enough to investigate, short enough to avoid unbounded growth
- Track DLQ depth as a metric alongside queue depth
- Each queue should have its own DLQ, not a shared DLQ — easier to identify the source
- Failed jobs contain the error message, attempt count, and original payload — log all three
- Idempotency check before replay — some jobs may have partially succeeded on a previous attempt
