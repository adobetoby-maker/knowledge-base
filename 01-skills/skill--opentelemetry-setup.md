# Skill: OpenTelemetry in Node.js

## Overview
OpenTelemetry (OTel) is the vendor-neutral standard for traces, metrics, and logs. The critical rule: the SDK must be bootstrapped in a separate file that is imported before any application code, because auto-instrumentation patches require hooks to be registered before the libraries load. Getting the import order wrong produces zero traces.

## Implementation

### Bootstrap File (import FIRST)
```typescript
// instrumentation.ts — must be the first import in your entry point
import { NodeSDK } from "@opentelemetry/sdk-node";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import { Resource } from "@opentelemetry/resources";
import { SEMRESATTRS_SERVICE_NAME, SEMRESATTRS_DEPLOYMENT_ENVIRONMENT } from "@opentelemetry/semantic-conventions";

const sdk = new NodeSDK({
  resource: new Resource({
    [SEMRESATTRS_SERVICE_NAME]: process.env.SERVICE_NAME ?? "unknown",
    [SEMRESATTRS_DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV ?? "development",
    "service.version": process.env.GIT_SHA ?? "local",
  }),
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,  // e.g. http://collector:4318/v1/traces
    headers: { "x-honeycomb-team": process.env.HONEYCOMB_API_KEY },
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      "@opentelemetry/instrumentation-http": { enabled: true },
      "@opentelemetry/instrumentation-pg": { enabled: true },
      "@opentelemetry/instrumentation-redis": { enabled: true },
      "@opentelemetry/instrumentation-fs": { enabled: false }, // too noisy
    }),
  ],
  // Sample 100% in dev, 10% in prod
  sampler: process.env.NODE_ENV === "production"
    ? new TraceIdRatioBasedSampler(0.1)
    : new AlwaysOnSampler(),
});

sdk.start();
process.on("SIGTERM", () => sdk.shutdown());
```

In your entry point:
```typescript
// server.ts
import "./instrumentation";   // MUST be first
import express from "express";
// ... rest of app
```

### Custom Spans
```typescript
import { trace, SpanStatusCode } from "@opentelemetry/api";

const tracer = trace.getTracer("my-service");

async function processInvoice(id: string) {
  return tracer.startActiveSpan("invoice.process", async (span) => {
    span.setAttribute("invoice.id", id);
    span.setAttribute("invoice.currency", "USD");
    try {
      const result = await doWork(id);
      span.setAttribute("invoice.line_items", result.lineItems.length);
      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (err) {
      span.recordException(err as Error);
      span.setStatus({ code: SpanStatusCode.ERROR, message: (err as Error).message });
      throw err;
    } finally {
      span.end();
    }
  });
}
```

### Exporters by Backend
| Backend | Exporter package | Notes |
|---|---|---|
| Grafana Tempo | `exporter-trace-otlp-http` | Set endpoint to Tempo OTLP endpoint |
| Datadog | `exporter-trace-otlp-http` | Use Datadog Agent as collector |
| Honeycomb | `exporter-trace-otlp-http` | Pass API key in headers |
| Jaeger | `exporter-jaeger` | Legacy; prefer OTLP |

## Key Rules
- Bootstrap file must be imported before everything else — auto-instrumentation won't patch modules already loaded
- Set `SERVICE_NAME` and `DEPLOYMENT_ENVIRONMENT` resources — without them, traces from different services are indistinguishable
- Set sample rate by environment: 1.0 in dev/staging, 0.1 or lower in production (traces are expensive at scale)
- Disable `fs` instrumentation — it fires on every file read and drowns useful traces
- Always call `span.end()` in a `finally` block — unclosed spans never export
- Add `service.version` (git SHA) to resource so you can correlate incidents to deploys
- Register a `SIGTERM` handler to flush the SDK before process exit — otherwise last batch of spans is lost
