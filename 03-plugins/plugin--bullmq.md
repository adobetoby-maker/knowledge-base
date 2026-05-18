# Plugin: BullMQ

## Overview

BullMQ is a Redis-backed job queue for Node.js. Jobs are added to queues and processed by workers. Key features over in-process solutions: jobs survive process restarts, workers can run on separate machines, jobs can be scheduled with delays or cron, failed jobs are retried automatically and stored for inspection.

## Install

```bash
npm install bullmq ioredis
```

## Queue Setup

```ts
import { Queue } from 'bullmq'
import IORedis from 'ioredis'

const connection = new IORedis(process.env.REDIS_URL, {
  maxRetriesPerRequest: null,  // Required by BullMQ
})

export const emailQueue = new Queue('email', { connection })
export const exportQueue = new Queue('export', { connection })
```

The `maxRetriesPerRequest: null` option is required by BullMQ — it allows blocking operations that wait indefinitely for jobs.

## Adding Jobs

```ts
// Simple job
await emailQueue.add('welcome-email', {
  userId: user.id,
  email: user.email,
})

// Delayed job — run after 5 minutes
await emailQueue.add('trial-reminder', { userId }, {
  delay: 5 * 60 * 1000,
})

// Scheduled with cron
await emailQueue.add('weekly-digest', {}, {
  repeat: { cron: '0 9 * * 1' },  // Monday 9am
})

// High priority job (lower number = higher priority)
await emailQueue.add('password-reset', { userId }, {
  priority: 1,
})

// Unique job by ID — prevents duplicates
await emailQueue.add('send-invoice', { invoiceId }, {
  jobId: `invoice-${invoiceId}`,
})
```

## Worker

```ts
import { Worker } from 'bullmq'

const emailWorker = new Worker(
  'email',
  async (job) => {
    switch (job.name) {
      case 'welcome-email':
        await sendWelcomeEmail(job.data.email, job.data.userId)
        break
      case 'trial-reminder':
        await sendTrialReminder(job.data.userId)
        break
      default:
        throw new Error(`Unknown job: ${job.name}`)
    }
  },
  {
    connection,
    concurrency: 5,           // Process up to 5 jobs in parallel
    limiter: {
      max: 100,               // Rate limit: max 100 jobs
      duration: 60 * 1000,    // per 60 seconds
    },
  }
)

emailWorker.on('completed', (job) => {
  console.log(`Job ${job.id} completed`)
})

emailWorker.on('failed', (job, error) => {
  console.error(`Job ${job?.id} failed:`, error.message)
})
```

## Retry Configuration

```ts
await emailQueue.add('send-email', data, {
  attempts: 3,
  backoff: {
    type: 'exponential',
    delay: 2000,  // 2s, 4s, 8s
  },
})
```

Failed jobs after all attempts move to the "failed" set — inspect them in Bull Board.

## Job Progress

```ts
// In worker
const worker = new Worker('export', async (job) => {
  const rows = await fetchAllRows()

  for (let i = 0; i < rows.length; i++) {
    await processRow(rows[i])
    await job.updateProgress(Math.round((i / rows.length) * 100))
  }
})

// In API route — check progress
const job = await exportQueue.getJob(jobId)
const progress = job?.progress  // 0–100
const state = await job?.getState()  // 'waiting' | 'active' | 'completed' | 'failed'
```

## Bull Board (Dashboard)

```ts
import { createBullBoard } from '@bull-board/api'
import { BullMQAdapter } from '@bull-board/api/bullMQAdapter'
import { ExpressAdapter } from '@bull-board/express'

const serverAdapter = new ExpressAdapter()
serverAdapter.setBasePath('/admin/queues')

createBullBoard({
  queues: [new BullMQAdapter(emailQueue), new BullMQAdapter(exportQueue)],
  serverAdapter,
})

app.use('/admin/queues', serverAdapter.getRouter())
```

## Job Results from API Route

```ts
// Route that starts a job and returns its ID
export async function POST(req: Request) {
  const { userId } = await req.json()
  const job = await exportQueue.add('csv-export', { userId })
  return Response.json({ jobId: job.id })
}

// Route that polls job status
export async function GET(req: Request, { params }: { params: { jobId: string } }) {
  const job = await exportQueue.getJob(params.jobId)
  if (!job) return new Response(null, { status: 404 })

  const state = await job.getState()
  const result = state === 'completed' ? job.returnvalue : null

  return Response.json({ state, progress: job.progress, result })
}
```

## Key Rules

- `maxRetriesPerRequest: null` on the IORedis connection is required — BullMQ will throw without it.
- Use `jobId` for idempotent jobs — adding a job with an existing `jobId` is a no-op if the job is still active or waiting.
- Workers must be started in a separate process from the web server (or at minimum a separate import path) — mixing queue workers with Next.js route handlers causes port conflicts and cold-start delays.
- Close the worker gracefully on shutdown: `await worker.close()` — this drains in-progress jobs before exiting.
- Never rely on in-memory state inside a worker — the job data object is the only state that persists across worker restarts.
