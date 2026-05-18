# Three Pillars of Observability

## What Observability Actually Means

Monitoring tells you when something is wrong. Observability tells you why. A system is observable if you can ask an arbitrary question about its internal state and get an answer — without deploying new code to add instrumentation.

The three pillars are not interchangeable. Each answers a different class of question. You need all three.

## Pillar 1: Logs

Logs answer: "What happened at this specific moment?"

Structured JSON logs, not plaintext:

```json
{ "ts": "2026-05-18T14:23:01.442Z", "level": "error", "trace_id": "trc_abc", "user_id": "usr_99", "service": "payments", "msg": "Payment processing failed", "amount": 149.00, "error_code": "insufficient_funds", "duration_ms": 234 }
```

Why structured: plaintext logs require regex parsing for any query. Structured logs let you filter by any field instantly. `level = "error" AND service = "payments" AND duration_ms > 500` is a four-second query with structured logs, a 20-minute regex puzzle with plaintext.

Every log line must include `trace_id`. Without it, logs from different services handling the same request are disconnected.

What to log: request received, request completed, external API calls (with duration), background job start/end, state transitions, errors with full context. Do NOT log PII, credentials, or request bodies without redaction.

## Pillar 2: Metrics

Metrics answer: "Is this system behaving normally over time?"

Three metric types:
- **Counter**: monotonically increasing count. `http_requests_total`, `errors_total`. Use for rates (requests/sec = delta over time).
- **Gauge**: current value. `active_connections`, `queue_depth`, `memory_bytes`. Snapshot a quantity right now.
- **Histogram**: distribution of values. `http_request_duration_ms`. Reveals p50/p90/p99 latency — the mean alone hides tail latency that users actually experience.

Metrics without labels are nearly useless. Always include: `service`, `endpoint`, `status_code`, `environment`. This lets you slice: "p99 latency for POST /checkout in production."

The four golden signals (from Google SRE):
1. **Latency** — how long requests take (p99, not mean)
2. **Traffic** — request rate
3. **Errors** — error rate (5xx, timeouts)
4. **Saturation** — how close to capacity (CPU%, queue depth)

Alert on golden signals. Not on individual metrics that may or may not matter.

## Pillar 3: Traces

Traces answer: "What path did this specific request take through the system?"

A trace is a tree of spans. The root span is the inbound request. Each downstream call (database query, external API, message queue publish) is a child span with its own timing.

```
[Root: POST /checkout — 340ms]
  [DB: SELECT orders — 12ms]
  [Service: validate-inventory — 45ms]
    [DB: SELECT inventory — 8ms]
    [Cache: GET inventory:item_99 — 2ms]
  [Service: payment-processor — 280ms]  ← bottleneck visible here
    [External: stripe.com — 275ms]
```

Without distributed tracing, this bottleneck would appear as "checkout is slow" with no indication that Stripe is the cause.

Every span should include: service name, operation name, duration, status, parent span ID, trace ID. Propagate trace context in HTTP headers (`traceparent` from W3C Trace Context standard) so spans from different services stitch together automatically.

## Why You Need All Three

| Question | Answered By |
|---|---|
| "Was there an error at 2:23?" | Logs |
| "Is error rate trending up this week?" | Metrics |
| "Why did this specific checkout take 5 seconds?" | Traces |
| "Which service is the bottleneck for p99 latency?" | Traces + Metrics |
| "What was the exact error message for request abc?" | Logs + Traces |

Metrics detect anomalies. Traces identify where in the system. Logs explain what happened within a service. Remove any one pillar and you're guessing at the intersection of the other two.

## Implementation Stack

A common open-source stack: OpenTelemetry SDK (instrumentation) → collector → Loki (logs), Prometheus (metrics), Tempo/Jaeger (traces) → Grafana (dashboards). OpenTelemetry is vendor-neutral — swap backends without re-instrumenting.

Instrument once in middleware/interceptors. Don't scatter instrumentation through business logic.

## Key Rules

- Logs must be structured JSON with `trace_id` on every line
- Metrics must have meaningful labels (service, endpoint, status); histograms for latency, not averages
- Traces must propagate context across service boundaries using W3C `traceparent`
- Alert on the four golden signals: latency (p99), traffic, error rate, saturation
- Use OpenTelemetry for instrumentation — vendor-neutral, single SDK for all three pillars
- All three pillars are required; each answers questions the others cannot
