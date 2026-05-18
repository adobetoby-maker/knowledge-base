# Review: Interpreting Load Test Results

## Overview
Load test output contains multiple metrics and most teams focus on the wrong one (average latency). Average latency hides the distribution — a p50 of 50ms looks great while 5% of users experience 5 seconds. Understanding which percentile maps to which user experience is the foundation of meaningful load test analysis.

## Implementation / Key Points

### Percentile Reference
| Percentile | Meaning | Use For |
|---|---|---|
| p50 (median) | Half of requests are faster than this | General health indicator only |
| p95 | 95% of requests complete within this | User experience benchmark |
| p99 | 99% complete within this | Catching long tails |
| p99.9 | 99.9% complete within this | SLA definitions |

**Never report average latency for web services.** A few slow requests inflate the average without revealing the true distribution.

### Reading a k6 / Grafana Output
```
http_req_duration...: avg=142ms  min=12ms  med=89ms  p(90)=310ms  p(95)=480ms  p(99)=1.2s
http_reqs...........: 4532   75.5/s
http_req_failed.....: 0.12%  5 requests
```
- p95 = 480ms → most users see under 500ms ✓
- p99 = 1.2s → 1% of users wait over a second — investigate
- error rate = 0.12% → under 1% threshold ✓

### Throughput Plateau = Bottleneck
When you ramp virtual users and RPS (requests per second) stops climbing while latency rises:
```
VUs: 100 → RPS: 850  → p95: 220ms
VUs: 200 → RPS: 860  → p95: 450ms  ← plateau begins
VUs: 300 → RPS: 862  → p95: 890ms  ← bottleneck confirmed
```
The service is saturated. Adding more users queues them up rather than increasing throughput. Check: CPU, DB connection pool, thread pool, downstream API limits.

### Latency Spike at Threshold = Queue Saturation
Sudden non-linear latency increase at a specific concurrency level points to a queue or connection pool limit:
```
VUs: 50  → p99: 200ms
VUs: 100 → p99: 210ms
VUs: 150 → p99: 1800ms  ← spike, not gradual
```
The cliff at 100→150 VUs suggests a pool of ~100 connections. Requests beyond that wait for a slot.

### Error Rate Thresholds
| Error Rate | Interpretation |
|---|---|
| < 0.1% | Baseline noise, acceptable |
| 0.1–1% | Degraded, investigate |
| > 1% | Service failing under load, stop test |
| Sudden spike | Circuit breaker tripped or downstream failing |

### What to Check After a Test
1. **Baseline comparison** — compare p95 against previous run, not just absolute value
2. **Error breakdown** — which status codes? 503 = capacity, 429 = rate limit, 500 = bugs
3. **Resource correlation** — CPU/memory/DB connections at the time of latency spikes
4. **GC pressure** (JVM/Node) — latency spikes at regular intervals often = GC pause
5. **Warm-up period** — first 30s of results often show cold-start latency, exclude from averages

### k6 Threshold Configuration
```javascript
export const options = {
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<2000'],
    http_req_failed: ['rate<0.01'],
  },
};
```

## Key Rules
- Always report p95 and p99 — never average for web latency
- A throughput plateau while latency climbs means the bottleneck is found, not that load is too high
- Error rate > 1% during a load test means the service is degrading — stop and investigate before pushing higher
- Compare results to a baseline from the previous run, not just absolute thresholds
- Exclude warm-up traffic (first ~30 seconds) from reported metrics
- Latency spikes that appear at regular intervals are often GC pauses, not load-related
- p99.9 matters only for SLA commitments — don't optimize p99.9 at the expense of p95
