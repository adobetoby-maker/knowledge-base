# Failure: Credentials and PII in Logs

## Overview
Logging request bodies, error messages with interpolated values, or full objects that happen to contain passwords, tokens, or PII is a critical security failure. Log files are less protected than databases — they're often accessible to a wider group of engineers, exported to third-party logging services, retained longer than necessary, and rarely encrypted. A password that appears in a log is effectively leaked to everyone with log access.

## How Credentials Get Logged

```ts
// BAD: logging the entire request body
app.post('/auth/login', (req, res) => {
  console.log('Login attempt:', req.body)  // { email: "...", password: "hunter2" }
  // ...
})

// BAD: logging error with SQL that contains interpolated values
async function findUser(email: string, password: string) {
  try {
    const user = await db.query(`SELECT * FROM users WHERE email='${email}'`)
    // ...
  } catch (err) {
    logger.error('Query failed:', err.message)  // May include the query with the password
  }
}

// BAD: logging tokens from auth headers
app.use((req, res, next) => {
  logger.info('Request:', req.method, req.url, req.headers)  // Includes Authorization: Bearer TOKEN
  next()
})

// BAD: logging entire error object that contains a database URL with password
logger.error('DB connection failed', err)  // err.config.url = "postgres://user:password@host/db"
```

## Fix 1: Allowlist approach — only log specific fields

```ts
// Define what is safe to log
function sanitizeForLogging(obj: Record<string, unknown>): Record<string, unknown> {
  const SAFE_FIELDS = new Set([
    'email', 'username', 'userId', 'role', 'action',
    'statusCode', 'method', 'path', 'duration', 'requestId',
  ])

  const SENSITIVE_FIELDS = new Set([
    'password', 'token', 'secret', 'key', 'authorization',
    'credit_card', 'ssn', 'cvv', 'pin', 'otp', 'cookie',
  ])

  return Object.fromEntries(
    Object.entries(obj)
      .filter(([key]) => !SENSITIVE_FIELDS.has(key.toLowerCase()))
      .map(([key, value]) => [
        key,
        SAFE_FIELDS.has(key.toLowerCase()) ? value : '[redacted]',
      ])
  )
}

// Usage
logger.info('Login attempt', sanitizeForLogging({ email, password, ip: req.ip }))
// Logs: { email: "user@example.com", password: "[redacted]", ip: "1.2.3.4" }
```

## Fix 2: Structured logging with explicit field selection

```ts
import pino from 'pino'

const logger = pino({
  redact: {
    paths: ['*.password', '*.token', '*.secret', '*.authorization', 'req.headers.authorization'],
    censor: '[REDACTED]',
  },
})

// Safe to log — redact handles sensitive paths
logger.info({ userId, action: 'login', ip: req.ip }, 'User login')
```

## Fix 3: Sentry beforeSend scrubbing

```ts
import * as Sentry from '@sentry/nextjs'

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  beforeSend(event) {
    // Scrub request bodies
    if (event.request?.data) {
      event.request.data = scrubSensitiveKeys(event.request.data)
    }

    // Scrub cookies
    if (event.request?.cookies) {
      event.request.cookies = '[removed]'
    }

    // Scrub breadcrumb data
    if (event.breadcrumbs?.values) {
      event.breadcrumbs.values = event.breadcrumbs.values.map(b => ({
        ...b,
        data: b.data ? scrubSensitiveKeys(b.data) : b.data,
      }))
    }

    return event
  },
})

function scrubSensitiveKeys(obj: unknown): unknown {
  if (typeof obj !== 'object' || obj === null) return obj
  const SENSITIVE = /password|token|secret|key|authorization|credit_card|ssn/i
  return Object.fromEntries(
    Object.entries(obj as Record<string, unknown>).map(([k, v]) => [
      k,
      SENSITIVE.test(k) ? '[REDACTED]' : scrubSensitiveKeys(v),
    ])
  )
}
```

## Fix 4: Never interpolate user values into SQL logs

```ts
// BAD: parameterized query still leaks values if logged wrong
try {
  const user = await db.query('SELECT * FROM users WHERE email = $1', [email])
} catch (err) {
  // BAD: don't log the parameters array
  logger.error('Query failed', { query: err.query, params: err.parameters })

  // GOOD: log only what's needed for debugging
  logger.error('User lookup failed', { email: email.replace(/@.*/, '@***'), errorCode: err.code })
}
```

## Fix 5: Database connection string safety

```ts
// Parse connection string before logging to remove credentials
function safeConnectionString(url: string): string {
  try {
    const parsed = new URL(url)
    parsed.password = '***'
    parsed.username = parsed.username ? '***' : ''
    return parsed.toString()
  } catch {
    return '[invalid connection string]'
  }
}

logger.info('Connecting to database', { url: safeConnectionString(process.env.DATABASE_URL!) })
```

## Key Rules
- Use an allowlist for what can be logged — not a blocklist (you'll miss new sensitive fields)
- Log user IDs, not passwords or tokens — IDs are useful for debugging; secrets are not
- HTTP Authorization headers must never appear in request logs
- Use structured logging (pino, winston) with built-in `redact` support
- Configure Sentry/Datadog `beforeSend`/`beforeLog` hooks to scrub PII before it leaves your server
- Database connection URLs contain credentials — never log them raw
- PII in logs: email addresses and IP addresses may require scrubbing depending on your privacy policy
- Audit your logging code when adding new request body fields — they may be logged if you log the whole body
