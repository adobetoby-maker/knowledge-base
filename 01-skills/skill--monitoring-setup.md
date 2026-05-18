# Monitoring Setup

Monitoring is the difference between learning about production failures from users and catching them in the first minutes. Each layer of the stack needs different tooling; a complete stack covers errors, performance, uptime, and logs.

## Error Tracking: Sentry

Sentry captures unhandled exceptions with full stack traces, breadcrumbs of prior user actions, and release tracking. Install the Next.js SDK:

```bash
npx @sentry/wizard@latest -i nextjs
```

This auto-configures `sentry.client.config.ts`, `sentry.server.config.ts`, source map upload on build, and the `instrumentation.ts` hook. Don't skip the source map upload step — without it, stack traces point to minified bundles, not source files.

Set `sampleRate: 1.0` in development, `0.1` in production for performance traces. Keep `tracesSampleRate` below 1.0 in production to avoid overwhelming your quota.

Alert on: new error rate exceeding baseline, any error affecting more than 1% of sessions, first occurrence of a new error class.

## Performance Monitoring: Vercel Analytics / Datadog

Vercel Analytics tracks Core Web Vitals (LCP, CLS, INP) per page, segmented by device and geography. Enable it in one line:

```tsx
// app/layout.tsx
import { Analytics } from '@vercel/analytics/react'
<Analytics />
```

For APM beyond web vitals, Datadog or New Relic trace server-side execution time, database query duration, and external API latency. These are valuable when diagnosing where server time is being spent, not just that a page is slow.

Set a performance budget: LCP < 2.5s, CLS < 0.1, INP < 200ms. Alert when p75 for any page exceeds these thresholds.

## Uptime Monitoring: Better Uptime / Cronitor

Uptime monitors hit your health check endpoint from multiple regions on a 1-minute interval. When the endpoint fails to respond within timeout, the alert fires. This catches: server down, deployment gone wrong, DNS failure, SSL cert expiry.

Expose a `/api/health` endpoint that checks: app is running, database connection is live, any critical external dependency is reachable. Return 200 with `{ status: "ok", db: "ok" }` or 500 with specifics.

Cronitor also monitors cron jobs — it expects a ping at each scheduled run and alerts if a ping is missed or overdue. Add a ping call at the end of every cron handler.

## Logging: Pino → Logtail / Axiom

Console.log in production is lost. Structured logging with Pino produces JSON log lines that log aggregators can index, filter, and alert on.

```ts
import pino from 'pino'
const logger = pino({ level: process.env.LOG_LEVEL || 'info' })
logger.info({ userId, action: 'payment.created', amount }, 'Payment created')
```

Ship logs to Logtail or Axiom via their Pino transport. Both support live tailing, retention, and alerting on log patterns.

Log: every request (method, path, status, duration), every external API call (service, duration, status), every background job (start, end, rows processed), every error with full context.

## Alerting Thresholds

Avoid alert fatigue by setting thresholds that require action, not just awareness:

| Signal | Alert threshold |
|---|---|
| Error rate | >1% of requests in 5-minute window |
| p99 latency | >3x baseline in 5-minute window |
| Uptime | First failure after 3 consecutive checks |
| Cron job | Missed expected window by >5 minutes |

Route production alerts to PagerDuty or a dedicated Slack `#incidents` channel. Don't mix deployment notifications with incident alerts — they get ignored together.

## Key Rules

- Install Sentry with source map upload on build — minified traces are useless
- Add a `/api/health` endpoint that checks DB connectivity; monitor it from 2+ regions
- Use structured logging (Pino JSON) and ship to a log aggregator — console.log is not monitoring
- Set alerting thresholds based on action-required signals, not just anomalies
- Monitor cron jobs with Cronitor or similar — missed jobs are silent failures without it
- Set performance budgets and alert when p75 exceeds them, not just when individual requests are slow
