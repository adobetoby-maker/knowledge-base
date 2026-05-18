# Disambig: Background Job Approach

## What Counts as a Background Job

Any work that should not block the user's request:
- Sending emails after a form submit
- Generating a PDF after an invoice is created
- Processing a batch of records
- Calling a slow external API
- Running scheduled tasks (daily reports, cleanup)

## Decision Tree

**Does it need to run on a schedule?**
- Yes → Vercel Cron (`vercel.json`) or Cloudflare Workers Cron trigger

**Is it triggered by a user action?**
- Should complete within the request → do it inline (fire-and-forget with `.catch()` for non-critical)
- May take > 5 seconds → queue it (see queueing options below)

**Can failure be silent (non-critical)?**
- Yes → fire-and-forget in Server Action / Route Handler
- No → queue with retry

## Fire-and-Forget (Simplest)

For non-critical work (analytics, audit logs, welcome emails with low urgency):

```typescript
// Server Action — fire and don't wait:
export async function createInvoice(data: CreateInvoiceData) {
  const invoice = await db.createInvoice(data)
  
  // Non-critical — log failure but don't fail the action:
  sendWelcomeEmail(invoice).catch(e => 
    console.error('Email failed for invoice', invoice.id, e)
  )
  
  return { success: true, data: invoice }
}
```

Limitation: if the server process dies between the response and the email, the email never sends.

## Vercel Cron (Scheduled Jobs)

For recurring tasks — daily reports, reminders, cleanup:

```json
// vercel.json:
{
  "crons": [{
    "path": "/api/cron/send-reminders",
    "schedule": "0 9 * * 1-5"  // 9 AM Mon-Fri
  }]
}
```

```typescript
// app/api/cron/send-reminders/route.ts
export async function GET(request: Request) {
  const authHeader = request.headers.get('authorization')
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return new Response('Unauthorized', { status: 401 })
  }
  
  const overdueInvoices = await getOverdueInvoices()
  for (const invoice of overdueInvoices) {
    await sendReminder(invoice)
  }
  
  return Response.json({ processed: overdueInvoices.length })
}
```

## Cloudflare Workers Cron

For workers deployed to Cloudflare (silver-creek `silvercreek-dispatch`):

```typescript
// wrangler.toml:
// [[triggers]]
// crons = ["*/30 * * * *"]  // every 30 minutes

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(runDispatchJob(env))
  }
}
```

## Queueing (For Reliable Delivery)

When fire-and-forget isn't reliable enough:

**Supabase + Postgres queue pattern:**
```sql
CREATE TABLE job_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_type text NOT NULL,
  payload jsonb NOT NULL,
  status text DEFAULT 'pending',
  attempts integer DEFAULT 0,
  last_error text,
  created_at timestamptz DEFAULT now(),
  scheduled_at timestamptz DEFAULT now()
);
```

```typescript
// Enqueue:
await supabase.from('job_queue').insert({
  job_type: 'send-invoice-email',
  payload: { invoiceId: invoice.id, recipientEmail: customer.email },
})

// Process (in cron):
const { data: jobs } = await supabase
  .from('job_queue')
  .select('*')
  .eq('status', 'pending')
  .lte('scheduled_at', new Date().toISOString())
  .order('scheduled_at')
  .limit(10)

for (const job of jobs ?? []) {
  try {
    await processJob(job)
    await supabase.from('job_queue').update({ status: 'completed' }).eq('id', job.id)
  } catch (error) {
    await supabase.from('job_queue')
      .update({ 
        status: job.attempts >= 3 ? 'failed' : 'pending',
        attempts: job.attempts + 1,
        last_error: (error as Error).message,
        scheduled_at: new Date(Date.now() + 5 * 60_000).toISOString()  // retry in 5 min
      })
      .eq('id', job.id)
  }
}
```

## When to Use Each

| Approach | When |
|---|---|
| Inline (await) | Fast, must succeed for the user |
| Fire-and-forget | Non-critical, OK to lose occasionally |
| Vercel Cron | Scheduled, predictable schedule |
| Cloudflare Cron | Worker deployed, Cloudflare-specific triggers |
| DB queue | Must not lose jobs, retry on failure |
