# Disambiguation: Background Job Strategy

## The Core Question

Where does the processing happen — and how does it get triggered?

| Option | Best For | Constraint |
|--------|----------|------------|
| Vercel Cron + Route Handler | Simple scheduled tasks, ≤ 5 min runtime | Serverless timeout (5 min free, 60 min pro) |
| GitHub Actions scheduled workflow | Dev/CI tasks, no Vercel limit | Requires repo, not suitable for user-triggered |
| Supabase Edge Functions + pg_cron | Database-proximate tasks, Postgres triggers | Deno runtime, no Node.js APIs |
| Upstash QStash | User-triggered background jobs, retries, delays | External HTTP calls only |
| Cloudflare Workers + Cron Trigger | CF-deployed apps, lightweight jobs | CF execution model (no long-running) |
| Long-running Node.js process | Jobs > 15 min, stateful workers | Requires persistent server (Railway, Fly.io) |

## Decision Tree

**Is this job user-triggered** (user action starts it)?
→ Yes → Use **QStash** or the same platform's queue
→ No (scheduled) → Continue

**Is it scheduled on a fixed interval?**
→ Yes → **Vercel Cron** (for Vercel apps) or **GitHub Actions schedule** (for repo tasks)

**Does it need to access the database directly or trigger on DB events?**
→ Yes → **Supabase Edge Functions + pg_cron** or database triggers
→ No → Continue

**Will it run longer than 5 minutes?**
→ Yes → GitHub Actions or a persistent server (Railway, Fly.io)
→ No → Vercel Cron

## Vercel Cron Configuration

```json
// vercel.json
{
  "crons": [
    {
      "path": "/api/cron/daily-report",
      "schedule": "0 6 * * *"   // 6am UTC daily
    },
    {
      "path": "/api/cron/cleanup",
      "schedule": "0 2 * * 0"   // 2am UTC every Sunday
    }
  ]
}
```

```ts
// app/api/cron/daily-report/route.ts
export async function GET(req: Request) {
  // Verify Vercel's cron authentication header
  if (req.headers.get('Authorization') !== `Bearer ${process.env.CRON_SECRET}`) {
    return new Response('Unauthorized', { status: 401 })
  }

  await generateDailyReport()
  return Response.json({ success: true })
}
```

## QStash for User-Triggered Jobs

```ts
// Trigger a background job from a route handler
import { Client } from '@upstash/qstash'

const qstash = new Client({ token: process.env.QSTASH_TOKEN! })

// In your route handler — respond immediately, process in background
await qstash.publishJSON({
  url: `${process.env.NEXT_PUBLIC_BASE_URL}/api/jobs/process-import`,
  body: { fileId, userId },
  delay: 0,             // Start immediately
  retries: 3,           // Retry on failure
  timeout: 300,         // 5 minute timeout
})

return Response.json({ status: 'processing', message: 'Import started' })
```

The user gets an immediate `200` response. QStash calls your endpoint asynchronously and retries on failure.

## GitHub Actions for Long Jobs

```yaml
# .github/workflows/weekly-report.yml
on:
  schedule:
    - cron: '0 7 * * 1'  # 7am UTC every Monday
  workflow_dispatch:

jobs:
  generate-report:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npx tsx scripts/weekly-report.ts
        env:
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
```

No Vercel timeout constraints. Runs on GitHub's infrastructure. Use for: data aggregation, large exports, AI batch processing, anything that might run 10–30+ minutes.

## Supabase pg_cron

```sql
-- Run every hour
SELECT cron.schedule('cleanup-expired-tokens', '0 * * * *',
  $$DELETE FROM magic_link_tokens WHERE expires_at < now()$$
);

-- Call Edge Function daily
SELECT cron.schedule('daily-email-digest', '0 8 * * *',
  $$SELECT net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/daily-digest',
    headers := '{"Authorization": "Bearer ' || current_setting('app.service_key') || '"}',
    body := '{}'
  )$$
);
```

pg_cron runs inside Postgres — ideal for database maintenance (vacuum, cleanup, aggregation) where the data lives.

## Retry and Failure Handling

Every background job must handle failure:
- **Idempotency**: Running the same job twice must be safe (use upsert, not insert)
- **Dead-letter queue**: Jobs that fail all retries must be logged and alertable
- **Timeout**: Every job must have a maximum runtime — kill it if exceeded
- **Alerting**: Job failures need to notify someone — not silently fail

See `batch--analytics-jobs.md` for the full idempotency pattern.
