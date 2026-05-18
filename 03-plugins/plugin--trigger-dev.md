# Plugin: Trigger.dev

## Overview

Trigger.dev runs long-running background jobs with durability guarantees. Unlike BullMQ (self-hosted Redis queue) or Inngest (cloud functions), Trigger.dev provides a cloud-hosted runtime that handles job persistence, retries, scheduling, and a real-time dashboard. Jobs are defined as TypeScript functions and deployed to the Trigger.dev cloud.

## Install

```bash
npx trigger.dev@latest init
npm install @trigger.dev/sdk
```

## Define a Job

```ts
// src/trigger/email.ts
import { task } from '@trigger.dev/sdk/v3'
import { sendWelcomeEmail } from '../lib/email'

export const welcomeEmailTask = task({
  id: 'welcome-email',
  retry: {
    maxAttempts: 3,
    factor: 2,
    minTimeoutInMs: 1000,
    maxTimeoutInMs: 10000,
  },
  run: async (payload: { userId: string; email: string }) => {
    await sendWelcomeEmail(payload.email, payload.userId)
    return { sent: true }
  },
})
```

## Trigger from API Route

```ts
import { welcomeEmailTask } from '@/trigger/email'

// In a Next.js route handler or Server Action
export async function POST(req: Request) {
  const { userId, email } = await req.json()
  const handle = await welcomeEmailTask.trigger({ userId, email })
  return Response.json({ runId: handle.id })
}
```

## Multi-Step Jobs

```ts
export const userOnboardingTask = task({
  id: 'user-onboarding',
  run: async (payload: { userId: string }) => {
    // Step 1: Create Stripe customer
    const stripeCustomer = await stripe.customers.create({
      metadata: { userId: payload.userId },
    })

    // Step 2: Provision storage bucket
    await createUserBucket(payload.userId)

    // Step 3: Send email after provisioning
    const user = await db.query.users.findFirst({ where: eq(users.id, payload.userId) })
    await resend.emails.send({
      to: user!.email,
      subject: 'Your account is ready',
    })

    return { stripeCustomerId: stripeCustomer.id }
  },
})
```

Unlike regular async functions, if the job fails at step 3, retrying starts from step 3 — not from the beginning. This is controlled by checkpoints in Trigger.dev's runtime.

## Scheduled / Cron Jobs

```ts
import { schedules } from '@trigger.dev/sdk/v3'

export const weeklyDigestTask = schedules.task({
  id: 'weekly-digest',
  cron: '0 9 * * 1',  // Every Monday at 9am UTC
  run: async (payload) => {
    const users = await db.query.users.findMany({ where: eq(users.digestEnabled, true) })
    await Promise.all(users.map(u => sendDigest(u.id)))
  },
})
```

## Waiting for Duration Inside a Job

```ts
import { wait } from '@trigger.dev/sdk/v3'

export const delayedFollowupTask = task({
  id: 'delayed-followup',
  run: async (payload: { userId: string }) => {
    await sendInitialEmail(payload.userId)
    await wait.for({ days: 3 })  // Non-blocking — job is paused, no compute cost
    await sendFollowupEmail(payload.userId)
  },
})
```

`wait.for` pauses the job without holding a server connection open — fundamentally different from `setTimeout` or `sleep`.

## Triggering Batches

```ts
await welcomeEmailTask.batchTrigger(
  users.map(u => ({ payload: { userId: u.id, email: u.email } }))
)
```

## Check Job Status

```ts
import { runs } from '@trigger.dev/sdk/v3'

const run = await runs.retrieve(runId)
// run.status: 'QUEUED' | 'EXECUTING' | 'COMPLETED' | 'FAILED' | 'CANCELED'
// run.output: the return value when COMPLETED
```

## Local Development

```bash
npx trigger.dev@latest dev
```

This runs a local tunnel that connects your local code to the Trigger.dev cloud — jobs triggered in dev hit your local function. No separate Redis needed.

## Key Rules

- Tasks are identified by their `id` string — changing an `id` creates a new task, it doesn't rename the old one.
- `wait.for` is the correct way to add delays inside jobs — it consumes no compute while waiting; a `setTimeout` would time out the function execution.
- The task `run` function must be idempotent — on retry, it runs from the beginning unless using explicit checkpoint patterns.
- Return values from `run` become `run.output` and are serializable JSON — don't return class instances or functions.
- Trigger.dev's free tier is suitable for low-volume jobs; self-hosted option exists for sensitive data that can't leave infrastructure.
