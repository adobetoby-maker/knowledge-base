# Background Jobs

## When to Use Background Jobs

Background jobs handle work that:
- Takes too long for a synchronous HTTP response (> 10 seconds)
- Should happen outside the user's request lifecycle
- Needs to be scheduled periodically (cron)
- Can tolerate some latency (send email after form submit)

## Vercel Cron Jobs

For Next.js projects on Vercel, cron jobs trigger Route Handlers:

```json
// vercel.json
{
  "crons": [
    {
      "path": "/api/cron/send-reminders",
      "schedule": "0 9 * * *"      // Daily at 9 AM UTC
    },
    {
      "path": "/api/cron/dispatch",
      "schedule": "*/30 * * * *"   // Every 30 minutes
    }
  ]
}
```

```typescript
// app/api/cron/send-reminders/route.ts
export async function GET(req: NextRequest) {
  // Validate the request is from Vercel's cron service
  const authHeader = req.headers.get('authorization')
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  // Run the job
  const supabase = createAdminClient()
  const { data: overdueInvoices } = await supabase
    .from('invoices')
    .select('id, customer_id, number')
    .eq('status', 'pending')
    .lt('due_date', new Date().toISOString().split('T')[0])

  let sent = 0
  for (const invoice of overdueInvoices ?? []) {
    await sendOverdueReminder(invoice)
    sent++
    await new Promise(r => setTimeout(r, 500))  // rate limit
  }

  return NextResponse.json({ sent })
}
```

## Cloudflare Worker Cron

For Cloudflare Workers (silver-creek-logistics dispatch, climb-* sites):
```toml
# wrangler.toml
[[triggers.crons]]
crons = ["0 */6 * * *"]  # every 6 hours
```

```typescript
// cloudflare-worker/index.ts
export default {
  async scheduled(controller: ScheduledController, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(runDispatch(env))  // non-blocking
  }
}
```

## Supabase pg_cron

For jobs that operate purely on database data, use pg_cron in Supabase:
```sql
-- Enable pg_cron extension in Supabase dashboard first
-- Then schedule SQL to run:
SELECT cron.schedule(
  'mark-overdue-invoices',           -- job name
  '0 2 * * *',                       -- daily at 2 AM
  $$
    UPDATE invoices
    SET status = 'overdue'
    WHERE status = 'pending'
      AND due_date < CURRENT_DATE
  $$
);

-- View scheduled jobs
SELECT jobname, schedule, command FROM cron.job;

-- Remove a job
SELECT cron.unschedule('mark-overdue-invoices');
```

This runs entirely in the database — no server required.

## Queueing with Supabase (Simple Pattern)

For jobs that shouldn't block a user action:
```sql
-- Job queue table
CREATE TABLE job_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL,           -- 'send_invoice_email', 'sync_to_quickbooks'
  payload JSONB NOT NULL,
  status TEXT DEFAULT 'pending', -- 'pending' | 'processing' | 'done' | 'failed'
  attempts INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  processed_at TIMESTAMPTZ
);
```

```typescript
// Queue a job (in Server Action or Route Handler)
await supabase.from('job_queue').insert({
  type: 'send_invoice_email',
  payload: { invoiceId: invoice.id, customerId: invoice.customer_id },
})
```

```typescript
// Worker (cron route, runs every minute)
export async function GET(req: NextRequest) {
  // Process up to 10 pending jobs
  const { data: jobs } = await supabase
    .from('job_queue')
    .select('*')
    .eq('status', 'pending')
    .lt('attempts', 3)
    .order('created_at')
    .limit(10)

  for (const job of jobs ?? []) {
    await supabase
      .from('job_queue')
      .update({ status: 'processing', attempts: job.attempts + 1 })
      .eq('id', job.id)

    try {
      await processJob(job)
      await supabase
        .from('job_queue')
        .update({ status: 'done', processed_at: new Date().toISOString() })
        .eq('id', job.id)
    } catch (error) {
      await supabase
        .from('job_queue')
        .update({ status: job.attempts >= 2 ? 'failed' : 'pending' })
        .eq('id', job.id)
    }
  }

  return NextResponse.json({ processed: jobs?.length ?? 0 })
}
```

## Handling Job Failures

- Retry logic: exponential backoff up to 3 attempts
- Dead letter: after 3 failures, mark as `failed` and alert
- Alert on failure: send Slack/email notification for failed critical jobs
- Idempotency: jobs should be safe to run multiple times (check if already done)

## Long-Running Jobs (> 10s)

Vercel functions have a max duration. For jobs exceeding it:
1. Use Cloudflare Workers (no duration limit for scheduled events)
2. Break into smaller chunks (process 100 items per cron invocation)
3. Use Supabase Edge Functions (can run longer)

```typescript
// Chunk processing: pick up where last run left off
const { data: jobs } = await supabase
  .from('job_queue')
  .select('*')
  .eq('status', 'pending')
  .order('created_at')
  .limit(50)  // only 50 per run → never exceeds timeout
```
