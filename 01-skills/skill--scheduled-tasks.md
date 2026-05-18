# Scheduled Tasks

## Why Cron Needs Infrastructure, Not Just a Timer

A bare `setInterval` or cron entry in a single process has three fatal flaws: it runs on every instance when scaled horizontally (duplicate runs corrupt data), it dies silently when the process restarts (no alerting), and there's no history of what ran, when, and whether it succeeded. A proper scheduled task system fixes all three.

## Cron Syntax Reference

```
┌──────────── minute (0–59)
│ ┌────────── hour (0–23)
│ │ ┌──────── day of month (1–31)
│ │ │ ┌────── month (1–12)
│ │ │ │ ┌──── day of week (0–7, 0 and 7 = Sunday)
│ │ │ │ │
* * * * *

0 2 * * *     → every day at 2:00 AM
0 */6 * * *   → every 6 hours
*/15 * * * *  → every 15 minutes
0 9 * * 1     → every Monday at 9:00 AM
0 0 1 * *     → first day of each month at midnight
```

Always express times in UTC in code. Convert to the user's timezone only in the UI.

## Distributed Lock: Preventing Duplicate Runs

When running multiple instances, only one should execute a scheduled job at a time. Use a distributed lock acquired at the start of each run:

```ts
async function runWithLock(jobName: string, ttlMs: number, fn: () => Promise<void>) {
  const lockKey = `lock:cron:${jobName}`;
  const acquired = await redis.set(lockKey, '1', 'NX', 'PX', ttlMs);
  if (!acquired) {
    logger.info({ job: jobName }, 'skipped — lock held by another instance');
    return;
  }
  try {
    await fn();
  } finally {
    await redis.del(lockKey); // release early on success
  }
}
```

Set TTL to the **maximum acceptable runtime** of the job, not its typical runtime. If the instance dies mid-run, the lock auto-expires after TTL so the next scheduled run can proceed. Too short a TTL causes duplicate runs; too long a TTL stalls recovery.

For Supabase-backed systems without Redis: use a `job_locks` table with `SELECT ... FOR UPDATE SKIP LOCKED` or the `pg_try_advisory_lock()` function.

## Execution Timeout

Jobs must have a hard timeout. A job that hangs forever holds the lock until TTL expiry and may accumulate unclosed DB connections:

```ts
async function withTimeout<T>(fn: () => Promise<T>, ms: number): Promise<T> {
  return Promise.race([
    fn(),
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error(`Job timed out after ${ms}ms`)), ms)
    ),
  ]);
}
```

When a timeout is hit: log the error, alert, and let the lock expire naturally. Do not retry immediately — the job may be stuck on an external dependency. Let the next scheduled run handle it.

## Job History and Task Table

Store a row per execution for observability and dashboard queries:

```sql
create table job_runs (
  id           uuid primary key default gen_random_uuid(),
  job_name     text not null,
  status       text not null check (status in ('running', 'success', 'failed', 'skipped')),
  started_at   timestamptz not null default now(),
  completed_at timestamptz,
  duration_ms  integer,
  error        text,         -- error message if failed
  meta         jsonb         -- job-specific stats: records processed, emails sent, etc.
);

create index on job_runs (job_name, started_at desc);
```

On job start: insert `{ status: 'running' }`. On success: update to `{ status: 'success', completed_at, duration_ms }`. On failure: update to `{ status: 'failed', error }`.

This table powers a simple admin dashboard showing last run time, duration trend, and failure history.

## Failure Alerting

Silent cron failures are the worst kind — the work doesn't happen and nobody knows. At minimum:

1. **Consecutive failure threshold**: alert after N consecutive failures (not every failure — transient errors are normal).
2. **Missed run detection**: if a job that runs every 6 hours has no `success` row in the last 8 hours, alert. The job may have stopped running entirely.
3. **Duration anomaly**: if a job that normally takes 2s suddenly takes 45s, something is wrong.

```ts
// After each run, check consecutive failure count
const recentRuns = await db.select()
  .from(jobRuns)
  .where(eq(jobRuns.job_name, jobName))
  .orderBy(desc(jobRuns.started_at))
  .limit(3);

const consecutiveFailures = recentRuns.findIndex(r => r.status === 'success');
if (consecutiveFailures >= 3) {
  await sendAlert(`Job ${jobName} has failed ${consecutiveFailures} times consecutively`);
}
```

## Idempotency

Scheduled jobs run at-least-once. Design them so running twice produces the same result as running once:

- Process records with `WHERE processed_at IS NULL` and mark them on processing.
- Use `INSERT ... ON CONFLICT DO NOTHING` instead of blind inserts.
- For external side effects (emails, webhooks): check a `sent_at` flag before firing.

## Platform Options

| Platform | Mechanism |
|----------|-----------|
| Vercel | `vercel.json` cron, calls a route handler |
| Cloudflare Workers | `[triggers] crons = ["0 * * * *"]` in `wrangler.toml` |
| Node.js server | `node-cron` or `cron` npm package |
| Managed | Trigger.dev, Inngest, QStash — built-in history and retry |

Managed platforms (Trigger.dev, Inngest) handle the distributed lock, history, retry, and alerting out of the box. Use them unless there's a strong reason to build the infrastructure manually.

## Key Rules

- **Distributed lock required** on multi-instance deployments — duplicate runs corrupt data.
- Set lock TTL to **maximum acceptable runtime**, not typical runtime.
- **Hard timeout** on every job — a hanging job is worse than a failed one.
- Store a **job_runs row** per execution for history, dashboards, and missed-run detection.
- Alert on **consecutive failures and missed runs**, not just individual failures.
- Design every job to be **idempotent** — it will run at-least-once.
- Express cron times in **UTC** in code; convert to user timezone only in the UI.
