# Plugin: Inngest

## Overview

Inngest is a durable background job and workflow platform. Functions run in serverless environments (Vercel, Cloudflare Workers, AWS Lambda) without a long-running process. Events trigger functions, steps are retried individually on failure, and state is persisted across multi-step flows. Alternative to Bull/BullMQ when you need serverless-compatible queues.

## Installation

```bash
npm install inngest
```

## Setup

```ts
// lib/inngest.ts
import { Inngest } from 'inngest'

export const inngest = new Inngest({
  id: 'my-app',
  // eventKey set via INNGEST_EVENT_KEY env var
})
```

## Route Handler (Next.js)

```ts
// app/api/inngest/route.ts
import { serve } from 'inngest/next'
import { inngest } from '@/lib/inngest'
import { sendWelcomeEmail, processUpload, monthlyReport } from '@/lib/functions'

export const { GET, POST, PUT } = serve({
  client: inngest,
  functions: [sendWelcomeEmail, processUpload, monthlyReport],
})
```

## Defining Functions

```ts
// lib/functions.ts
import { inngest } from './inngest'

// Simple event-triggered function
export const sendWelcomeEmail = inngest.createFunction(
  { id: 'send-welcome-email' },
  { event: 'user/signup' },
  async ({ event, step }) => {
    const user = event.data  // { id, email, name }

    await step.run('send-email', async () => {
      await sendEmail({
        to: user.email,
        template: 'welcome',
        data: { name: user.name },
      })
    })

    await step.sleep('wait-3-days', '3 days')

    await step.run('send-followup', async () => {
      const hasLoggedIn = await db.query.users.findFirst({
        where: and(eq(users.id, user.id), isNotNull(users.lastLoginAt)),
      })

      if (!hasLoggedIn) {
        await sendEmail({ to: user.email, template: 'onboarding-nudge' })
      }
    })
  }
)
```

## Multi-Step with Retry

Each `step.run` is retried independently — failure in step 2 won't re-run step 1:

```ts
export const processUpload = inngest.createFunction(
  {
    id: 'process-upload',
    retries: 3,
    concurrency: { limit: 10 },       // Max 10 concurrent executions
  },
  { event: 'file/uploaded' },
  async ({ event, step }) => {
    const { fileKey, userId } = event.data

    // Step 1: Download and extract metadata
    const metadata = await step.run('extract-metadata', async () => {
      const buffer = await downloadFile(fileKey)
      return extractImageMetadata(buffer)
    })

    // Step 2: Generate thumbnails (uses result from step 1)
    await step.run('generate-thumbnails', async () => {
      await generateThumbnails(fileKey, metadata.dimensions)
    })

    // Step 3: Update database
    await step.run('update-db', async () => {
      await db.update(files)
        .set({ processed: true, width: metadata.dimensions.width, height: metadata.dimensions.height })
        .where(eq(files.key, fileKey))
    })
  }
)
```

## Cron Jobs

```ts
export const monthlyReport = inngest.createFunction(
  { id: 'monthly-report' },
  { cron: '0 8 1 * *' },  // 8AM UTC on the 1st of every month
  async ({ step }) => {
    const orgs = await step.run('fetch-orgs', () =>
      db.query.organizations.findMany({ where: eq(organizations.active, true) })
    )

    // Fan-out: send one event per org (parallel processing)
    await step.sendEvent('send-report-events', orgs.map(org => ({
      name: 'report/generate',
      data: { orgId: org.id },
    })))
  }
)
```

## Triggering Events from Your App

```ts
// In a route handler or server action
await inngest.send({
  name: 'user/signup',
  data: {
    id: user.id,
    email: user.email,
    name: user.name,
  },
})

// Multiple events at once
await inngest.send([
  { name: 'order/created', data: { orderId, userId } },
  { name: 'inventory/reserve', data: { items } },
])
```

## Key Rules

- Each `step.run` call is a durable checkpoint — if the function fails mid-run, Inngest replays from the last completed step.
- Never perform side effects outside of `step.run` — they'll re-execute on replay.
- `step.sleep` pauses execution without holding a serverless function open — it resumes as a new invocation.
- Idempotency: `step.run` results are memoized by step ID — the same function with the same step ID won't re-execute.
- Local dev: run `npx inngest-cli@latest dev` to start a local Inngest server that captures events from your Next.js dev server.
