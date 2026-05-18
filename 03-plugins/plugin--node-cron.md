# Plugin: node-cron / Cron Scheduling

## Overview

Run recurring background tasks on a schedule (cron expressions). Common uses: daily reports, cleanup jobs, reminder emails, data sync, cache warming. Two approaches: `node-cron` for long-running Node servers, Vercel/Cloudflare cron triggers for serverless.

## node-cron (For Persistent Servers)

```bash
npm install node-cron
```

```ts
import cron from 'node-cron'

// Run every day at 2:30 AM
cron.schedule('30 2 * * *', async () => {
  console.log('Running daily cleanup...')
  try {
    await runDailyCleanup()
  } catch (err) {
    console.error('Cleanup failed:', err)
    // Alert via Slack/email — don't let silent failures go unnoticed
    await alertOnCall('Daily cleanup failed', err)
  }
}, {
  timezone: 'America/New_York',  // Always specify timezone
  scheduled: true,
})
```

## Cron Expression Reference

```
┌─────── minute (0-59)
│ ┌───── hour (0-23)
│ │ ┌─── day of month (1-31)
│ │ │ ┌─ month (1-12)
│ │ │ │ ┌ day of week (0-7, 0=Sunday)
│ │ │ │ │
* * * * *

Examples:
0 * * * *      Every hour at :00
0 9 * * 1-5   9 AM Mon-Fri
*/15 * * * *  Every 15 minutes
0 0 1 * *     First day of each month at midnight
0 2 * * *     Daily at 2 AM
```

## Vercel Cron Jobs

```json
// vercel.json
{
  "crons": [
    {
      "path": "/api/cron/daily-cleanup",
      "schedule": "0 2 * * *"
    },
    {
      "path": "/api/cron/send-reminders",
      "schedule": "0 9 * * *"
    }
  ]
}
```

```ts
// app/api/cron/daily-cleanup/route.ts
export async function GET(req: Request) {
  // Verify this is actually from Vercel Cron
  const authHeader = req.headers.get('authorization')
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    await runDailyCleanup()
    return Response.json({ ok: true })
  } catch (err) {
    console.error('Cron failed:', err)
    return Response.json({ error: String(err) }, { status: 500 })
  }
}
```

Vercel cron requires `CRON_SECRET` env var set in both Vercel dashboard and your `.env`.

## Cloudflare Workers Cron Triggers

```ts
// worker.ts
export default {
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(runDailyJob(env))
  },
}
```

```toml
# wrangler.toml
[triggers]
crons = ["0 2 * * *"]
```

## Idempotent Cron Jobs

Jobs can run twice (restart, manual trigger, infrastructure retry). Make them safe to run multiple times:

```ts
async function sendWeeklyDigest() {
  // Check if already sent this week
  const lastSent = await db.query.cronLog.findFirst({
    where: and(
      eq(cronLog.jobName, 'weekly-digest'),
      gte(cronLog.ranAt, startOfWeek(new Date())),
    ),
  })
  if (lastSent) {
    console.log('Weekly digest already sent this week, skipping')
    return
  }

  await sendDigestEmails()
  
  // Record completion
  await db.insert(cronLog).values({ jobName: 'weekly-digest', ranAt: new Date() })
}
```

## Key Rules

- Always specify `timezone` — cron expressions with no timezone are in UTC, which is often wrong for business hours jobs.
- Protect cron endpoints with `CRON_SECRET` — otherwise anyone can trigger your jobs.
- Log job start, completion, and duration — cron failures are silent by default.
- Make jobs idempotent — infrastructure retries and overlapping runs are real.
- For long-running jobs (>10s on serverless): use a queue (Bull/SQS) instead of running inline in the cron endpoint.
