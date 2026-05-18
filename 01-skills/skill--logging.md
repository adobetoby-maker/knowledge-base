# Logging and Observability

## What to Log

Log at system boundaries and decision points. Not inside every function.

**Always log:**
- Incoming requests to Route Handlers with context (method, path, user ID if auth'd)
- External API calls with timing
- Database errors with query context
- Auth events (login, logout, token refresh)
- Background job start/end/error
- Webhook receipt and processing result

**Don't log:**
- Every database read (creates noise)
- Passwords, tokens, API keys, PII
- Objects that contain sensitive fields without redacting

## Structured Logging

Structured logs (JSON) are searchable. Unstructured strings are not.

```typescript
// lib/logger.ts
type LogLevel = 'debug' | 'info' | 'warn' | 'error'

interface LogEntry {
  level: LogLevel
  message: string
  timestamp: string
  [key: string]: unknown
}

export const logger = {
  info(message: string, context?: Record<string, unknown>) {
    console.log(JSON.stringify({ level: 'info', message, timestamp: new Date().toISOString(), ...context }))
  },
  warn(message: string, context?: Record<string, unknown>) {
    console.warn(JSON.stringify({ level: 'warn', message, timestamp: new Date().toISOString(), ...context }))
  },
  error(message: string, context?: Record<string, unknown>) {
    console.error(JSON.stringify({ level: 'error', message, timestamp: new Date().toISOString(), ...context }))
  },
}
```

```typescript
// Usage
logger.info('Invoice created', { invoiceId: invoice.id, userId: user.id, amount: invoice.total })
logger.error('Stripe webhook failed', { eventId: event.id, error: err.message })
```

## Request Context Logging

Add a request ID to trace a single request through all logs:

```typescript
// app/api/invoices/route.ts
import { headers } from 'next/headers'
import { logger } from '@/lib/logger'

export async function POST(req: NextRequest) {
  const requestId = crypto.randomUUID()
  const headersList = await headers()
  const userId = headersList.get('x-user-id') ?? 'anonymous'
  
  const log = {
    info: (msg: string, ctx = {}) => logger.info(msg, { requestId, userId, ...ctx }),
    error: (msg: string, ctx = {}) => logger.error(msg, { requestId, userId, ...ctx }),
  }
  
  log.info('Invoice creation started')
  
  try {
    const result = await createInvoice(data)
    log.info('Invoice created', { invoiceId: result.id })
    return NextResponse.json(result)
  } catch (err) {
    log.error('Invoice creation failed', { error: (err as Error).message })
    return NextResponse.json({ error: 'Internal error' }, { status: 500 })
  }
}
```

## Vercel Logs

View in Vercel dashboard → Functions → Logs, or via CLI:
```bash
vercel logs --prod        # production logs
vercel logs               # preview logs
vercel logs --follow      # tail logs in real time
```

JSON logs automatically get structured display in Vercel's log viewer.

## Supabase Logs

Via Supabase MCP or dashboard → Logs:
```typescript
// Via MCP
mcp__plugin_supabase_supabase__get_logs({ project_id, service: 'api', limit: 100 })

// Filter by error in the dashboard: status_code >= 400
```

## Error Monitoring (Sentry)

For production error tracking beyond console logs:

```typescript
// lib/sentry.ts
import * as Sentry from '@sentry/nextjs'

export function captureError(error: Error, context?: Record<string, unknown>) {
  Sentry.captureException(error, { extra: context })
  logger.error(error.message, { ...context, stack: error.stack })
}

// In error boundaries and catch blocks
captureError(err, { invoiceId, userId, action: 'create-invoice' })
```

## Performance Logging

Log slow operations to identify bottlenecks:

```typescript
async function withTiming<T>(label: string, fn: () => Promise<T>): Promise<T> {
  const start = performance.now()
  try {
    const result = await fn()
    const ms = Math.round(performance.now() - start)
    if (ms > 1000) logger.warn(`Slow operation: ${label}`, { durationMs: ms })
    else logger.info(`Operation: ${label}`, { durationMs: ms })
    return result
  } catch (err) {
    const ms = Math.round(performance.now() - start)
    logger.error(`Failed operation: ${label}`, { durationMs: ms, error: (err as Error).message })
    throw err
  }
}

// Usage
const invoices = await withTiming('fetch-user-invoices', () => 
  supabase.from('invoices').select('*').eq('user_id', userId)
)
```

## Cloudflare Workers Logging

Workers logs appear in Wrangler tail:
```bash
wrangler tail   # streams live logs from deployed worker
```

Log from Workers:
```typescript
// All console.log/warn/error output is captured in wrangler tail
console.log(JSON.stringify({ event: 'webhook_received', type: event.type }))
```

## What NOT to Log

```typescript
// BAD — logs sensitive data
logger.info('User login', { email, password })
logger.info('Stripe customer', { customerId, paymentMethod: card })
logger.info('Supabase response', { data: fullUserObject })  // may contain tokens

// GOOD — log IDs not values
logger.info('User login', { userId: user.id })
logger.info('Payment processed', { customerId, invoiceId })
logger.info('DB query complete', { table: 'invoices', rowCount: data.length })
```
