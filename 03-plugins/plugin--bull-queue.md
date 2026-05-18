# Plugin: BullMQ (Job Queue)

## Overview

BullMQ is a Redis-backed job queue for Node.js. Use it for: background jobs, scheduled tasks, delayed execution, retries, rate-limiting, and multi-worker concurrency. Requires Redis — not available on serverless or Cloudflare Workers.

## Install

```bash
npm install bullmq
npm install ioredis  # Redis client (peer dependency)
```

## Setup

```ts
// lib/queue.ts
import { Queue, Worker, QueueEvents } from 'bullmq'
import { Redis } from 'ioredis'

const connection = new Redis(process.env.REDIS_URL!, {
  maxRetriesPerRequest: null,  // Required by BullMQ
})

export const emailQueue = new Queue('emails', { connection })
export const invoiceQueue = new Queue('invoices', { connection })
```

## Adding Jobs

```ts
// Add a job immediately
await emailQueue.add('send-welcome', {
  userId: 'u_abc123',
  email: 'jane@example.com',
  templateId: 'welcome-v2',
})

// Add with options
await emailQueue.add('send-digest', { userId }, {
  delay: 5 * 60 * 1000,    // Delay 5 minutes
  attempts: 3,              // Retry up to 3 times
  backoff: {
    type: 'exponential',
    delay: 2000,            // 2s, 4s, 8s
  },
  removeOnComplete: 100,    // Keep last 100 completed jobs
  removeOnFail: 200,        // Keep last 200 failed jobs
})

// Scheduled recurring job
await emailQueue.add('daily-digest', {}, {
  repeat: { cron: '0 9 * * *' },  // 9am every day
})
```

## Worker

```ts
// workers/email-worker.ts
import { Worker } from 'bullmq'

const worker = new Worker('emails', async (job) => {
  const { userId, email, templateId } = job.data

  // Log progress
  await job.updateProgress(10)

  const user = await getUser(userId)
  await job.updateProgress(50)

  await sendEmail({ to: email, templateId, user })
  await job.updateProgress(100)

  // Return value stored in job.returnvalue
  return { sent: true, messageId: 'msg_abc' }
}, {
  connection,
  concurrency: 5,  // Process 5 jobs simultaneously
})

worker.on('completed', (job, result) => {
  console.log(`Job ${job.id} completed`, result)
})

worker.on('failed', (job, err) => {
  console.error(`Job ${job.id} failed:`, err.message)
})
```

Workers run in a separate process (or the same process in dev). Start them separately from your API server in production.

## Job Events

```ts
import { QueueEvents } from 'bullmq'

const events = new QueueEvents('emails', { connection })

events.on('completed', ({ jobId, returnvalue }) => {
  console.log(`${jobId} done:`, returnvalue)
})

events.on('failed', ({ jobId, failedReason }) => {
  console.error(`${jobId} failed:`, failedReason)
})

events.on('progress', ({ jobId, data }) => {
  console.log(`${jobId} progress:`, data)
})
```

## Rate Limiting

```ts
const worker = new Worker('api-calls', handler, {
  connection,
  limiter: {
    max: 100,          // Max 100 jobs
    duration: 60000,   // Per 60 seconds
  },
})
```

## Priority Queue

```ts
// Higher priority = processed first (1 is highest)
await queue.add('urgent-invoice', data, { priority: 1 })
await queue.add('bulk-export', data, { priority: 10 })
```

## Checking Job Status

```ts
const job = await emailQueue.getJob(jobId)

if (!job) return null

const state = await job.getState()
// 'waiting' | 'active' | 'completed' | 'failed' | 'delayed' | 'paused'

// Get all jobs in a state
const failedJobs = await emailQueue.getFailed(0, 50)  // First 50 failed
const waitingJobs = await emailQueue.getWaiting(0, 10)
```

## Graceful Shutdown

```ts
process.on('SIGTERM', async () => {
  await worker.close()    // Wait for active jobs to finish
  await connection.quit()
  process.exit(0)
})
```

Never kill a worker abruptly — in-progress jobs get marked as stale and retried.

## When NOT to Use BullMQ

- **Serverless / Vercel**: No persistent process. Use Vercel Cron + database job table instead.
- **Cloudflare Workers**: No Redis. Use Workers Queues or cron triggers.
- **Simple cron jobs**: Vercel `vercel.json` cron or GitHub Actions is simpler.
- **Real-time requirements**: BullMQ adds latency. For <100ms tasks, call directly.

Use BullMQ when: you need reliable retries, job history, concurrency control, rate limiting, or priority queuing in a persistent Node.js server.
