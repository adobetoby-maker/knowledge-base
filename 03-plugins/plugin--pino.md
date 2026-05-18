# Plugin: Pino

## Overview

Pino is the fastest Node.js logger. It writes JSON logs to stdout and offloads formatting to a separate process (pino-pretty for development). Use it in production APIs, background workers, and serverless functions.

## Install

```bash
npm install pino
npm install --save-dev pino-pretty
```

## Basic Setup

```ts
// lib/logger.ts
import pino from 'pino'

const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  ...(process.env.NODE_ENV === 'development' && {
    transport: {
      target: 'pino-pretty',
      options: { colorize: true, translateTime: 'SYS:HH:MM:ss' },
    },
  }),
})

export default logger
```

Production: plain JSON to stdout, consumed by log aggregator (Datadog, CloudWatch, Loki).
Development: formatted, colorized, human-readable via pino-pretty.

## Log Levels

```ts
logger.trace('Very verbose — disabled in prod')
logger.debug('Debug info')
logger.info('Normal operation')
logger.warn('Something unexpected but non-fatal')
logger.error({ err, requestId }, 'Request failed')
logger.fatal('About to crash')
```

Always pass structured data as the first argument, message as second:

```ts
// Wrong — unstructured
logger.info(`User ${userId} logged in`)

// Right — structured (queryable in log aggregator)
logger.info({ userId, sessionId }, 'User logged in')
```

## Child Loggers

Create child loggers with bound context for request-scoped logging:

```ts
// In a request handler
const reqLogger = logger.child({ 
  requestId: req.headers['x-request-id'],
  userId: req.user?.id,
  method: req.method,
  path: req.path,
})

reqLogger.info('Request received')
// → { "level": "info", "requestId": "abc", "userId": "u_123", "msg": "Request received" }

reqLogger.error({ err }, 'Handler threw')
// → same context fields automatically included
```

## Serializers

Define how complex objects are serialized to avoid logging sensitive data:

```ts
const logger = pino({
  serializers: {
    req: (req) => ({
      method: req.method,
      url: req.url,
      userAgent: req.headers['user-agent'],
      // Intentionally exclude: authorization, cookie, body
    }),
    err: pino.stdSerializers.err,  // Standard error serializer (stack trace)
    res: (res) => ({
      statusCode: res.statusCode,
    }),
  },
})
```

`pino.stdSerializers.err` correctly serializes `Error` objects including stack traces. Always use it for `err` fields.

## Express / Next.js Middleware

```ts
// express
import expressPino from 'express-pino-logger'
app.use(expressPino({ logger }))

// manual request logging in Next.js Route Handler
export async function GET(req: Request) {
  const reqLogger = logger.child({ 
    requestId: crypto.randomUUID(),
    path: new URL(req.url).pathname,
  })
  
  const start = Date.now()
  
  try {
    const result = await handler(reqLogger)
    reqLogger.info({ duration: Date.now() - start }, 'Request complete')
    return Response.json(result)
  } catch (err) {
    reqLogger.error({ err, duration: Date.now() - start }, 'Request failed')
    return Response.json({ error: 'Internal server error' }, { status: 500 })
  }
}
```

## Async Context (Node.js)

For automatic context propagation without passing logger everywhere:

```ts
import { AsyncLocalStorage } from 'async_hooks'

const loggerStorage = new AsyncLocalStorage<pino.Logger>()

export function getLogger() {
  return loggerStorage.getStore() ?? logger
}

export function runWithLogger<T>(requestLogger: pino.Logger, fn: () => T): T {
  return loggerStorage.run(requestLogger, fn)
}
```

## Cloudflare Workers / Edge Runtime

Pino uses `process.stdout` which isn't available in edge runtimes. Use console instead, or use a Pino transport that works in edge environments:

```ts
// Edge-compatible minimal logger
const logger = {
  info: (obj: object, msg?: string) => console.log(JSON.stringify({ level: 'info', ...obj, msg })),
  error: (obj: object, msg?: string) => console.error(JSON.stringify({ level: 'error', ...obj, msg })),
  warn: (obj: object, msg?: string) => console.warn(JSON.stringify({ level: 'warn', ...obj, msg })),
}
```

For Cloudflare Workers, structured `console.log` output is captured in Workers Logpush.

## Log Level by Environment

| Environment | Level |
|-------------|-------|
| Development | `debug` |
| Staging | `debug` or `info` |
| Production | `info` |
| Production (noisy) | `warn` |

Never use `trace` in production — too verbose. Use `debug` temporarily during investigation, then remove.

## Pino vs Winston

| | Pino | Winston |
|--|------|---------|
| Speed | ~5x faster | Moderate |
| JSON output | Native | Configurable |
| Formatting | Separate process (pino-pretty) | Built-in |
| Edge runtime | No (needs shim) | No |
| Ecosystem | Smaller | Large |

Use Pino for high-throughput Node.js APIs. The performance difference is measurable in production at scale.
