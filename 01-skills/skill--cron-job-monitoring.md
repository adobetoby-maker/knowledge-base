# Skill: Cron Job Health Monitoring

## Overview
Cron jobs fail silently by default — no output, no alert, no retry. A job that stops running is often invisible until data is stale or invoices haven't sent for a week. Monitoring requires an external service that expects a "heartbeat" ping and alerts when the ping stops. The job itself must be idempotent (safe to run twice) and must log structured output for every execution.

## Healthcheck Pattern (healthchecks.io / Cronitor)

The monitoring service expects a ping within a defined window. If no ping arrives, it alerts.

```ts
// lib/cron-monitor.ts
const HEALTHCHECK_URL = process.env.HEALTHCHECK_URL // e.g. https://hc-ping.com/<uuid>

export async function cronMonitor(jobName: string, fn: () => Promise<void>) {
  const start = Date.now()
  console.log(JSON.stringify({ event: 'cron_start', job: jobName, ts: new Date().toISOString() }))

  // Ping /start to indicate the job began
  await fetch(`${HEALTHCHECK_URL}/start`).catch(() => {})

  try {
    await fn()
    const duration = Date.now() - start
    console.log(JSON.stringify({ event: 'cron_end', job: jobName, duration_ms: duration }))

    // Success ping — resets the window
    await fetch(HEALTHCHECK_URL).catch(() => {})
  } catch (err) {
    const duration = Date.now() - start
    console.error(JSON.stringify({ event: 'cron_error', job: jobName, duration_ms: duration, error: String(err) }))

    // Failure ping — triggers alert immediately
    await fetch(`${HEALTHCHECK_URL}/fail`).catch(() => {})
    throw err // re-throw so the process exits non-zero
  }
}
```

Usage:

```ts
// app/api/cron/dispatch/route.ts
import { cronMonitor } from '@/lib/cron-monitor'

export async function GET(req: Request) {
  await cronMonitor('dispatch-sync', async () => {
    await runDispatchSync()
  })
  return new Response('ok')
}
```

## Idempotency Requirements

Cron jobs must be restartable without side effects.

```ts
// BAD — double-run sends duplicate emails
async function sendWeeklyReports() {
  const users = await db.users.findAll()
  for (const user of users) {
    await sendEmail(user.email, renderReport(user))
  }
}

// GOOD — track sent status, skip already-sent
async function sendWeeklyReports() {
  const weekId = getWeekId() // e.g. "2025-W20"
  const users = await db.users.findAll({
    where: { weeklyReportSentFor: { not: weekId } },
  })
  for (const user of users) {
    await sendEmail(user.email, renderReport(user))
    await db.users.update({ where: { id: user.id }, data: { weeklyReportSentFor: weekId } })
  }
}
```

Use a DB flag, a processed-IDs table, or upsert semantics to make every operation idempotent.

## Retry Strategy

Retry transient failures (network, timeout) — not logic failures.

```ts
async function retryable<T>(fn: () => Promise<T>, attempts = 3, delayMs = 1000): Promise<T> {
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn()
    } catch (err) {
      if (i === attempts - 1) throw err
      console.warn(`Attempt ${i + 1} failed, retrying in ${delayMs}ms:`, err)
      await new Promise(r => setTimeout(r, delayMs * (i + 1))) // exponential backoff
    }
  }
  throw new Error('unreachable')
}
```

Alert after N retries are exhausted — don't silently swallow the final failure.

## Structured Logging Template

Every cron execution must emit:

```ts
// Start
{ event: 'cron_start', job: string, ts: string }

// Success
{ event: 'cron_end', job: string, duration_ms: number, records_processed?: number }

// Error
{ event: 'cron_error', job: string, duration_ms: number, error: string, stack?: string }
```

Structured logs (JSON lines) can be queried in Datadog, CloudWatch, Papertrail — plain text logs cannot.

## Key Rules
- Never silently catch errors inside a cron job — always log and re-throw
- Ping `/start` at job begin and `/fail` on exception — gives exact failure window
- Use a separate healthcheck URL per cron job, not a shared one
- Set the healthcheck window to 2× the cron interval (a job that runs hourly → 2h window)
- Every destructive operation (delete, send, charge) must be gated by an idempotency check
- Log job duration — sudden slowdowns (5s → 45s) are early failure signals
- Test the failure path: deliberately throw an error and verify the alert fires
