# Plugin: OpenTelemetry

## Overview

OpenTelemetry (OTel) is the standard for distributed tracing, metrics, and logging. Instrument Node.js apps to trace requests across services, identify slow spans, and correlate logs. For Next.js, use the `@vercel/otel` package (simplifies setup) or configure directly with `@opentelemetry/sdk-node`.

## Installation (Next.js with Vercel)

```bash
npm install @vercel/otel @opentelemetry/api
```

```ts
// instrumentation.ts (in project root, NOT in src/)
import { registerOTel } from '@vercel/otel'

export function register() {
  registerOTel({
    serviceName: 'my-app',
    // Auto-instruments: http, fetch, postgres, redis
  })
}
```

```ts
// next.config.ts
const nextConfig = {
  experimental: {
    instrumentationHook: true,
  },
}
```

## Manual Tracing

```ts
import { trace, context, SpanStatusCode } from '@opentelemetry/api'

const tracer = trace.getTracer('my-app', '1.0.0')

async function processOrder(orderId: string): Promise<Order> {
  return tracer.startActiveSpan('process-order', async (span) => {
    span.setAttribute('order.id', orderId)

    try {
      const order = await tracer.startActiveSpan('db.fetch-order', async (dbSpan) => {
        dbSpan.setAttribute('db.statement', 'SELECT orders WHERE id = ?')
        const result = await db.query.orders.findFirst({ where: eq(orders.id, orderId) })
        dbSpan.end()
        return result
      })

      if (!order) {
        span.setStatus({ code: SpanStatusCode.ERROR, message: 'Order not found' })
        span.end()
        return null
      }

      span.setAttribute('order.status', order.status)
      span.setAttribute('order.total_cents', order.totalCents)
      span.setStatus({ code: SpanStatusCode.OK })
      span.end()
      return order
    } catch (err) {
      span.recordException(err as Error)
      span.setStatus({ code: SpanStatusCode.ERROR })
      span.end()
      throw err
    }
  })
}
```

## Custom Spans in React Server Components

```ts
// In a Server Component or Route Handler
import { trace } from '@opentelemetry/api'

export async function GET(req: Request) {
  const span = trace.getActiveSpan()
  span?.setAttribute('http.user_agent', req.headers.get('user-agent') ?? '')

  const data = await fetchData()
  return Response.json(data)
}
```

## Metrics

```ts
import { metrics } from '@opentelemetry/api'

const meter = metrics.getMeter('my-app')

// Counter
const requestCounter = meter.createCounter('http.requests', {
  description: 'Total HTTP requests',
})

// Histogram for latency
const latencyHistogram = meter.createHistogram('http.request.duration', {
  description: 'HTTP request duration in ms',
  unit: 'ms',
})

// Use in middleware
export async function middleware(req: NextRequest) {
  const start = Date.now()
  const res = await NextResponse.next()
  const duration = Date.now() - start

  requestCounter.add(1, {
    method: req.method,
    path: req.nextUrl.pathname,
    status: res.status.toString(),
  })

  latencyHistogram.record(duration, {
    method: req.method,
    path: req.nextUrl.pathname,
  })

  return res
}
```

## Export to Backend

```bash
# Send to Grafana Cloud / Jaeger / Honeycomb
npm install @opentelemetry/exporter-otlp-http
```

```ts
// instrumentation.ts with custom exporter
import { NodeSDK } from '@opentelemetry/sdk-node'
import { OTLPTraceExporter } from '@opentelemetry/exporter-otlp-http'

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
    headers: {
      Authorization: `Bearer ${process.env.OTEL_AUTH_TOKEN}`,
    },
  }),
  serviceName: 'my-app',
})

sdk.start()
```

## Key Rules

- `instrumentation.ts` must be in the project root alongside `package.json`, not inside `src/` — Next.js loads it before the app starts.
- `experimental.instrumentationHook: true` is required in `next.config.ts` for the instrumentation file to be picked up.
- Always call `span.end()` in a `finally` block — unclosed spans cause memory leaks.
- Add semantic attributes (`db.statement`, `http.method`, `user.id`) for useful filtering in your trace viewer.
- For Vercel deployments: `@vercel/otel` routes traces to Vercel's built-in observability tab automatically, no exporter needed.
