# Observability

## Three Pillars

1. **Logging** — what happened and when (structured, searchable)
2. **Metrics** — how the system is performing over time (counters, latencies)
3. **Tracing** — how a request flowed through the system (distributed)

For small projects, logging + error tracking covers most debugging needs. Add metrics when you need to track trends (request volume, error rates). Add tracing when you have multiple services and need to follow a request across them.

## Structured Logging

Log JSON, not strings. Fields, not concatenation:

```typescript
// WRONG — hard to search, parse, or alert on:
console.log('Invoice ' + id + ' failed: ' + error.message)

// CORRECT — every field is searchable:
console.error(JSON.stringify({
  event: 'invoice.create.failed',
  invoiceId: id,
  userId: user.id,
  error: error.message,
  timestamp: new Date().toISOString(),
}))
```

## Log Levels

```typescript
// Use the right level:
console.log()    // debug/info — routine operations
console.warn()   // recoverable issues — degraded service, retries
console.error()  // failures that need attention

// Never log sensitive data:
// BAD:
console.log('Auth with key:', apiKey)  // key in logs
// GOOD:
console.log('Auth with key:', apiKey.slice(0, 8) + '...')  // masked
```

## Sentry Integration (Next.js)

```bash
npx @sentry/wizard@latest -i nextjs
```

```typescript
// Captures uncaught errors, promise rejections, and React boundaries
// Sentry.init() is called by the wizard setup

// Manual capture for caught errors you still want tracked:
import * as Sentry from '@sentry/nextjs'

try {
  await riskyOperation()
} catch (error) {
  Sentry.captureException(error, {
    tags: { area: 'invoice-creation' },
    extra: { invoiceId: id, userId: user.id },
  })
  return { success: false, error: 'Operation failed' }
}
```

## Server Action Logging

Instrument server actions for timing and error tracking:

```typescript
// lib/instrumented-action.ts
export function instrumentedAction<TInput, TOutput>(
  name: string,
  fn: (input: TInput) => Promise<TOutput>
) {
  return async (input: TInput): Promise<TOutput> => {
    const start = Date.now()
    
    try {
      const result = await fn(input)
      console.log(JSON.stringify({
        event: `action.${name}.success`,
        durationMs: Date.now() - start,
      }))
      return result
    } catch (error) {
      console.error(JSON.stringify({
        event: `action.${name}.failed`,
        durationMs: Date.now() - start,
        error: (error as Error).message,
      }))
      throw error
    }
  }
}

// Usage:
export const createInvoice = instrumentedAction('createInvoice', async (data) => {
  // ... implementation
})
```

## Health Check Endpoint

Every deployed service should have a health check:

```typescript
// app/api/health/route.ts
import { NextResponse } from 'next/server'
import { supabaseServer } from '@/lib/supabase/server'

export async function GET() {
  const checks: Record<string, 'ok' | 'error'> = {}
  
  // Check database:
  try {
    await supabaseServer().from('profiles').select('id').limit(1)
    checks.database = 'ok'
  } catch {
    checks.database = 'error'
  }
  
  const allOk = Object.values(checks).every(v => v === 'ok')
  
  return NextResponse.json(
    { status: allOk ? 'ok' : 'degraded', checks },
    { status: allOk ? 200 : 503 }
  )
}
```

Uptime monitors (Better Uptime, UptimeRobot) hit this every 30 seconds and alert when it returns non-200.

## What to Always Log

In a web app, always log:
- Auth events: login, logout, failed login (without passwords)
- Mutations: create, update, delete on any important entity
- External API calls: which service, duration, success/fail
- Background job completion: job name, item count, duration, errors

Do NOT log:
- Passwords, tokens, secrets of any kind
- PII by default (email, phone) — log user ID instead, look up if needed
- Every GET request — too noisy; log slow queries (> 500ms) instead

## Cloudflare Workers Logging

Cloudflare Workers don't have persistent console — use `wrangler tail` during dev, and Workers Logpush for production:

```typescript
// In a Worker:
export default {
  async fetch(request, env, ctx) {
    const log = (msg: object) => console.log(JSON.stringify(msg))
    
    log({ event: 'request.start', url: request.url, method: request.method })
    
    const response = await handleRequest(request, env)
    
    log({ event: 'request.complete', status: response.status })
    return response
  }
}
```
