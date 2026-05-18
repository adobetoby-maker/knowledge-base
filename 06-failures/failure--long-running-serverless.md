# Failure: Long-Running Operations in Serverless Functions

## Overview
Serverless functions have hard execution time limits: Vercel Hobby is 10s, Vercel Pro is 60s (or 300s for streaming), AWS Lambda default is 3s (max 900s), Cloudflare Workers is 30s CPU time. Database migrations, file processing, report generation, and AI inference with large contexts regularly exceed these limits. The fix is always the same: move long work to a job queue and return a job ID immediately. Never extend timeouts as a solution — you're working against the platform's design.

## The Pattern That Fails

```ts
// BAD — user waits for 30+ second operation in a single HTTP request
export async function POST(req: Request) {
  const { reportType, dateRange } = await req.json()

  // Takes 45 seconds — times out on Vercel Hobby
  const report = await generateLargeReport(reportType, dateRange)

  return Response.json({ report })  // user never sees this
}
```

Timeout behavior: Vercel returns 504, AWS Lambda returns 504 or silently terminates. The operation may have completed but the user sees an error.

## The Fix: Enqueue + Poll

```ts
// GOOD — return job ID immediately
export async function POST(req: Request) {
  const { reportType, dateRange } = await req.json()

  const jobId = crypto.randomUUID()

  // Enqueue with BullMQ, Inngest, or similar
  await reportQueue.add('generate-report', {
    jobId, reportType, dateRange,
    userId: getCurrentUserId(req),
  })

  return Response.json({ jobId, status: 'queued' }, { status: 202 })
}

// Poll endpoint
export async function GET(req: Request) {
  const jobId = new URL(req.url).searchParams.get('jobId')!
  const job = await db.reportJobs.findUnique({ where: { id: jobId } })

  return Response.json({
    status: job?.status ?? 'not_found',  // queued | running | complete | failed
    result: job?.status === 'complete' ? job.result : undefined,
  })
}
```

## Streaming for AI Generation

For AI text generation, streaming lets content reach the user before the full response is ready:

```ts
// Next.js App Router streaming response
export async function POST(req: Request) {
  const { prompt } = await req.json()

  const stream = new TransformStream()
  const writer = stream.writable.getWriter()
  const encoder = new TextEncoder()

  // Start streaming immediately
  ;(async () => {
    const response = await anthropic.messages.stream({
      model: 'claude-haiku-4-5',
      max_tokens: 2048,
      messages: [{ role: 'user', content: prompt }],
    })

    for await (const chunk of response) {
      if (chunk.type === 'content_block_delta' && chunk.delta.type === 'text_delta') {
        await writer.write(encoder.encode(chunk.delta.text))
      }
    }
    await writer.close()
  })()

  return new Response(stream.readable, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  })
}
```

Streaming keeps the connection alive and delivers partial results — user sees progress before timeout.

## Inngest for Long Background Jobs

```ts
// lib/inngest/functions.ts
import { inngest } from './client'

export const generateReport = inngest.createFunction(
  { id: 'generate-report', timeout: '15m' },  // Inngest handles the timeout
  { event: 'report/generate' },
  async ({ event, step }) => {
    const { jobId, reportType, dateRange } = event.data

    await step.run('fetch-data', async () => {
      return await fetchReportData(dateRange)
    })

    await step.run('generate-pdf', async () => {
      return await generatePDF(reportType)
    })

    await step.run('save-and-notify', async () => {
      await db.reportJobs.update({
        where: { id: jobId },
        data: { status: 'complete', resultUrl: pdfUrl },
      })
      await sendEmail(event.data.userEmail, 'Your report is ready', pdfUrl)
    })
  }
)

// Trigger from route handler
await inngest.send({ name: 'report/generate', data: { jobId, ...payload } })
```

## Cold Start Impact

Serverless cold starts add 300ms–3s to function startup time. This counts against timeout:

- A 10s timeout with a 2s cold start leaves 8s for actual work
- Database connections that take 500ms during cold start further reduce available time

Use connection pooling (PgBouncer, Prisma Accelerate) to minimize cold start latency.

## Key Rules
- Operations that may take > 5 seconds belong in a job queue, not in an HTTP handler
- Return `202 Accepted` with a job ID for background work — poll or use webhooks for completion
- Stream AI responses — don't wait for the full completion before responding
- Inngest, BullMQ, and AWS SQS are the right tools for long background work
- Never extend timeouts as a "fix" — it just delays the timeout error by minutes
- Cold starts count against timeout — use connection pooling and lazy initialization to minimize
- Display job progress in the UI (polling or WebSocket) — never leave users with a spinning indicator indefinitely
