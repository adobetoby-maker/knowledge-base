# Metrics Collection

Application metrics are how you know something broke before a user reports it, and how you prove a deploy improved or degraded performance. The gap between "we have logging" and "we have metrics" is the difference between investigating incidents reactively and catching them proactively.

## The Three Metric Types

**Counter** — a value that only goes up. Use for: requests served, errors thrown, jobs processed, payments attempted. Never reset a counter in production. Derive rates from counters (requests/second = delta over time window).

**Gauge** — a value that goes up and down. Use for: current active connections, queue depth, cache size, memory in use. Represents a snapshot of state right now.

**Histogram** — distribution of values over a time window. Use for: request duration, payload size, job execution time. Histograms let you compute percentiles (p50, p95, p99). A mean response time of 200ms can hide that 1% of requests take 10 seconds — histograms expose this. Counters and gauges cannot.

## Prometheus-Style Metrics

Prometheus is the de facto standard for metric collection. Even if you don't run Prometheus, its data model (labels, scrape endpoints, PromQL-style queries) is what Datadog, Grafana Cloud, and most modern observability tools understand.

Core patterns:
- `http_requests_total{method="POST", path="/api/invoices", status="200"}` — counter with labels
- `http_request_duration_seconds{method="POST", path="/api/invoices"}` — histogram
- `db_pool_connections_active` — gauge

Labels are how you slice data. Keep label cardinality low — don't use user IDs, request IDs, or any unbounded values as labels. High cardinality explodes metric storage.

## OpenTelemetry in Next.js

OpenTelemetry (OTel) is the standard SDK for emitting metrics, traces, and logs. For Next.js:

1. Install `@opentelemetry/sdk-node`, `@opentelemetry/auto-instrumentations-node`, and your exporter (e.g., `@opentelemetry/exporter-prometheus` or `@opentelemetry/exporter-otlp-http`).
2. Create `instrumentation.ts` at the project root — Next.js loads it before the app on the server side.
3. Initialize the SDK with `NodeSDK` in `instrumentation.ts` → export to a collector or Prometheus endpoint.
4. Create custom meters via `@opentelemetry/api`'s `metrics.getMeter('app-name')` and call `.createCounter()`, `.createHistogram()`, etc.

Next.js runs in edge and serverless contexts where long-lived processes don't exist. Batch export with short intervals (5–10s), not on-process-exit. On Vercel, use an OTLP HTTP exporter pointed at a collector you control or a vendor endpoint.

## Dashboard Setup

In Grafana or Datadog, create a service overview board with four panels minimum:

1. **Request rate** (requests/minute) — counter derivative
2. **Error rate** (errors/minute, or % of requests) — alerts when elevated
3. **Latency** (p50/p95/p99 histogram) — alerts when p99 exceeds SLO
4. **Saturation** (queue depth, db pool usage, memory) — leading indicator before things break

Put the dashboard URL in the project README. Dashboards that require hunting to find are dashboards that aren't used during incidents.

## Alerting: Anomaly vs Threshold

**Threshold alerting** fires when a metric crosses an absolute value (`error_rate > 5%`). Easy to set up, works well for SLO violations. Problem: the right threshold changes as traffic grows.

**Anomaly alerting** fires when a metric deviates significantly from its historical baseline (e.g., request rate drops 50% below the same hour yesterday). Better for catching unknown unknowns — a traffic cliff, a silent failure, a data source going dark.

Use both: threshold alerts for your SLOs (latency, error rate, uptime) and anomaly detection for business metrics (signups, payments, API call volume). The combination catches "the site is up but nothing is working."

## Key Rules

- Counters for cumulative events, gauges for current state, histograms for distributions — never use gauge where a counter is correct
- Keep label cardinality bounded — no user IDs, request IDs, or session IDs as labels
- Expose a `/metrics` endpoint (Prometheus format) or use OTLP HTTP export; don't rely on log scraping for metrics
- Track p99 latency, not just p50/mean — averages hide tail latency
- Threshold alerts for SLOs, anomaly alerts for business metrics
- Dashboard URL in README; panels for rate, errors, latency, saturation
- Instrument at the framework/middleware layer, not in individual route handlers
