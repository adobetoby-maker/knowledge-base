# Skill: cron-background-jobs

**Trigger:** Implementing scheduled tasks, background processing, or async jobs.
**Returns:** Vercel cron, Cloudflare Workers cron, and queue-based patterns.

## When to Use Each Approach

| Need | Use |
|------|-----|
| Run every N minutes/hours | Vercel Cron Jobs or Cloudflare Workers scheduled triggers |
| Long-running task (>10s) | Queue-based (Cloudflare Queues, Supabase pg_cron) |
| Task triggered by user action but processed async | Background API call with waitUntil (Workers) or queue |
| Database cleanup, aggregation | pg_cron extension in Supabase |

## Vercel Cron Jobs

```json
// vercel.json
{
  "crons": [
    {
      "path": "/api/cron/daily-report",
      "schedule": "0 9 * * *"
    },
    {
      "path": "/api/cron/dispatch",
      "schedule": "*/30 * * * *"
    }
  ]
}
```

The route handler receives a GET request from Vercel's cron system. Protect it:

```typescript
// app/api/cron/daily-report/route.ts
export async function GET(request: Request) {
  // Verify cron secret
  const authHeader = request.headers.get('authorization')
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return new Response('Unauthorized', { status: 401 })
  }
  
  await generateDailyReport()
  return Response.json({ ok: true })
}
```

Vercel sets `CRON_SECRET` automatically in production. In development, set it manually or skip the check.

**Limits:**
- Hobby plan: max 2 cron jobs, once per day minimum interval
- Pro plan: unlimited cron jobs, minimum interval 1 minute

## Cloudflare Workers Scheduled Triggers

```typescript
// worker.ts
export default {
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(processScheduledWork(env))
  },
  
  async fetch(request: Request, env: Env): Promise<Response> {
    // Regular request handling
  }
}
```

```toml
# wrangler.toml
[[triggers]]
crons = ["0 * * * *"]      # every hour
# crons = ["*/5 * * * *"]  # every 5 minutes
# crons = ["0 9 * * 1"]    # Monday 9am UTC
```

## Supabase pg_cron (Database-Level Jobs)

```sql
-- Enable extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule a job
SELECT cron.schedule(
  'cleanup-old-sessions',
  '0 2 * * *',  -- 2am daily
  $$
    DELETE FROM sessions WHERE expires_at < now() - interval '7 days'
  $$
);

-- List scheduled jobs
SELECT * FROM cron.job;

-- Remove a job
SELECT cron.unschedule('cleanup-old-sessions');
```

pg_cron runs directly in the database — no external infrastructure needed. Best for database maintenance tasks.

## Cloudflare Queues — Async Task Processing

For tasks that need more than 10ms of CPU or must survive failures:

```typescript
// Producer (add to queue)
await env.QUEUE.send({
  type: 'send-invoice',
  payload: { invoiceId, email }
})

// Consumer (process from queue)
export default {
  async queue(batch: MessageBatch<TaskMessage>, env: Env) {
    for (const message of batch.messages) {
      try {
        await processMessage(message.body, env)
        message.ack()
      } catch (error) {
        message.retry()  // Will retry up to 3 times
      }
    }
  }
}
```

## Cron Expression Reference

```
* * * * *
│ │ │ │ └─ Day of week (0-7, Sunday = 0 or 7)
│ │ │ └─── Month (1-12)
│ │ └───── Day of month (1-31)
│ └─────── Hour (0-23)
└───────── Minute (0-59)

Examples:
0 9 * * *      → Every day at 9am UTC
0 9 * * 1      → Every Monday at 9am UTC
*/5 * * * *    → Every 5 minutes
0 */6 * * *    → Every 6 hours
0 0 1 * *      → First of every month at midnight
```

## Safety Pattern: Idempotent Jobs

All cron jobs should be idempotent — running twice with the same parameters should produce the same result as running once:

```typescript
// Bad — double-runs create duplicates
await insertReport({ date: today, data })

// Good — upsert prevents duplicates
await supabase.from('reports').upsert({ date: today, ...data }, { onConflict: 'date' })
```

## Monitoring Cron Jobs

Log every job execution:
```typescript
await supabase.from('cron_log').insert({
  job_name: 'daily-report',
  started_at: new Date().toISOString(),
  status: 'running'
})

// ... job runs ...

await supabase.from('cron_log').update({ status: 'completed', completed_at: new Date().toISOString() })
  .eq('job_name', 'daily-report').eq('status', 'running')
```

Alert if a job hasn't run within 2× its expected interval.
