# Skill: Distributed Tracing

## Overview
In a distributed system, a single user request touches multiple services, queues, and databases. When something is slow or broken, logs from individual services don't tell you which hop is responsible. Distributed tracing links all those spans under one trace ID, giving you a waterfall view of exactly where time was spent and where errors occurred. OpenTelemetry is the standard — vendor-agnostic instrumentation that exports to any backend.

## Implementation

### 1. SDK setup (Node.js)
```ts
// instrumentation.ts — must be imported BEFORE any other app code
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { Resource } from '@opentelemetry/resources';
import { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION } from '@opentelemetry/semantic-conventions';
import { TraceIdRatioBasedSampler } from '@opentelemetry/sdk-trace-node';
import { HttpInstrumentation } from '@opentelemetry/instrumentation-http';
import { PgInstrumentation } from '@opentelemetry/instrumentation-pg';

const sdk = new NodeSDK({
  resource: new Resource({
    [ATTR_SERVICE_NAME]: 'order-service',
    [ATTR_SERVICE_VERSION]: process.env.DEPLOY_VERSION ?? 'local',
    'deployment.environment': process.env.NODE_ENV,
  }),
  
  // 10% sampling in prod — 100% for errors (handled by ParentBased sampler)
  sampler: new TraceIdRatioBasedSampler(
    process.env.NODE_ENV === 'production' ? 0.1 : 1.0
  ),

  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT ?? 'http://localhost:4318/v1/traces',
  }),

  // Auto-instrument HTTP calls and Postgres — no manual instrumentation needed
  instrumentations: [
    new HttpInstrumentation(),
    new PgInstrumentation(),
  ],
});

sdk.start();
process.on('SIGTERM', () => sdk.shutdown());
```

### 2. Propagate trace context across service calls
```ts
import { context, trace, propagation } from '@opentelemetry/api';

// When calling another service — inject trace context into headers
async function callInventoryService(productId: string) {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };

  // Inject traceparent/tracestate headers automatically
  propagation.inject(context.active(), headers);

  const response = await fetch(`${INVENTORY_URL}/products/${productId}`, { headers });
  return response.json();
}

// When receiving a request — extract and continue the trace
app.use((req, res, next) => {
  const ctx = propagation.extract(context.active(), req.headers);
  context.with(ctx, next);  // all spans created in this request use the extracted context
});
```

### 3. Add span attributes for searchability
```ts
import { trace, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('order-service');

async function processOrder(orderId: string, userId: string) {
  // Create a custom span around the business operation
  return tracer.startActiveSpan('order.process', async (span) => {
    // Add attributes that you'll search/filter by in your tracing backend
    span.setAttributes({
      'order.id': orderId,
      'user.id': userId,
      'order.type': 'standard',
    });

    try {
      const result = await doProcessing(orderId);
      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (err) {
      // Mark error — sampler will keep 100% of error traces
      span.recordException(err as Error);
      span.setStatus({ code: SpanStatusCode.ERROR, message: (err as Error).message });
      throw err;
    } finally {
      span.end();
    }
  });
}
```

### 4. Database query duration tracking (manual when ORM isn't auto-instrumented)
```ts
async function queryWithTrace<T>(name: string, fn: () => Promise<T>): Promise<T> {
  const tracer = trace.getTracer('db');
  return tracer.startActiveSpan(`db.${name}`, async (span) => {
    const start = Date.now();
    try {
      const result = await fn();
      span.setAttribute('db.duration_ms', Date.now() - start);
      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (err) {
      span.recordException(err as Error);
      span.setStatus({ code: SpanStatusCode.ERROR });
      throw err;
    } finally {
      span.end();
    }
  });
}

// Usage
const order = await queryWithTrace('getOrder', () =>
  db.orders.findUnique({ where: { id: orderId } })
);
```

### 5. Export to Grafana Tempo / Honeycomb / Jaeger
```bash
# docker-compose for local Jaeger
services:
  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "4318:4318"   # OTLP HTTP receiver
      - "16686:16686" # UI
```

```bash
# env var for production export
OTEL_EXPORTER_OTLP_ENDPOINT=https://api.honeycomb.io
OTEL_EXPORTER_OTLP_HEADERS=x-honeycomb-team=YOUR_KEY
```

## Key Rules
- **10% sampling in prod, 100% for errors** — 100% sampling of all traffic is expensive; missing errors is unacceptable. Use `ParentBased(TraceIdRatioBased)` to keep full error traces.
- **Propagate `traceparent` header on every downstream call** — without propagation, traces break at service boundaries and you lose the full waterfall.
- Set `service.name` and `deployment.environment` as resource attributes — these are how you filter traces by service in your backend.
- Add `user.id` and `request.id` as span attributes — makes it possible to find all traces for a specific user complaint.
- Record exceptions on spans with `span.recordException()` — this attaches the stack trace to the span, visible in your tracing UI.
- Auto-instrumentation (HTTP, DB drivers) captures most spans for free — manual spans are for business logic boundaries.
- Always call `span.end()` in a `finally` block — unclosed spans never export.
