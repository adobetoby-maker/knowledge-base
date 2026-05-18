# Plugin: sentry@claude-plugins-official

**What it provides:** Error tracking, performance monitoring, AI-powered issue investigation.
**When to reach for it:** Investigating production errors, setting up error monitoring, analyzing error trends.

## Key Skills
- `sentry:seer` — AI-powered root cause analysis for Sentry issues
- `sentry:sentry-workflow` — end-to-end Sentry workflow
- `sentry:sentry-sdk-setup` — add Sentry SDK to a project
- `sentry:sentry-feature-setup` — configure specific Sentry features

## MCP Tools
```javascript
// Load schemas
ToolSearch("sentry")

// The Sentry MCP requires authentication first
mcp__plugin_sentry_sentry__authenticate({})
```

## Setting Up Sentry in Next.js
```bash
npx @sentry/wizard@latest -i nextjs
# Wizard: creates sentry.client.config.ts, sentry.server.config.ts, sentry.edge.config.ts
# Updates next.config.ts to wrap with withSentryConfig
```

```typescript
// sentry.client.config.ts
import * as Sentry from '@sentry/nextjs'
Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  tracesSampleRate: 0.1,  // 10% of transactions
  replaysOnErrorSampleRate: 1.0,  // 100% of error sessions
})
```

## Using Sentry for Error Investigation
When a production error is reported:
1. Go to Sentry dashboard → find the error event
2. Get the event ID or issue ID
3. Use `sentry:seer` skill for AI root cause analysis
4. Seer cross-references the stack trace with your source code

## Error Boundaries in React
```typescript
// app/error.tsx — Next.js App Router error boundary
'use client'
import * as Sentry from '@sentry/nextjs'
import { useEffect } from 'react'

export default function Error({ error, reset }: { error: Error; reset: () => void }) {
  useEffect(() => {
    Sentry.captureException(error)
  }, [error])

  return (
    <div>
      <h2>Something went wrong</h2>
      <button onClick={reset}>Try again</button>
    </div>
  )
}
```

## Manual Error Capture
```typescript
// Capture with context
Sentry.captureException(error, {
  extra: { userId, action: 'checkout', orderId }
})

// Breadcrumbs for tracing user path
Sentry.addBreadcrumb({
  message: 'User clicked checkout',
  category: 'ui.click',
  level: 'info'
})
```

## vs Runtime Logs
- **Vercel Runtime Logs** — raw function output, good for server-side errors, last ~24-48 hours
- **Sentry** — structured error tracking with stack traces, user context, release tracking, long retention
Use both: Vercel logs for "what just happened", Sentry for "how often does this happen and to whom"
