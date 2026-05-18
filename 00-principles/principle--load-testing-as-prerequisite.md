# Principle: Load Testing as Prerequisite

## Overview
Performance problems are invisible until they're catastrophic. A database query that takes 50ms with 10 users takes 5000ms with 1000 concurrent users because of connection pool contention and lock waits. Load testing before launch and after architectural changes is how you find this out at 2pm on a Tuesday instead of during a product launch with press coverage.

## When Load Testing is Required

- Before every major public launch (new product, high-profile marketing campaign)
- After any change to: database schema, query patterns, caching layer, external API integrations
- When scaling tier changes (moving from 1 to 3 instances, upgrading DB plan)
- When adding a new high-traffic endpoint

## The Right Metric: p95 Latency

Average latency is misleading. If 95% of requests take 100ms and 5% take 10,000ms, the average is ~600ms — looks fine, but 1 in 20 users has a terrible experience.

- **p50 (median):** What a typical user experiences
- **p95:** What the slowest 1 in 20 users experiences — the target metric
- **p99:** What the slowest 1 in 100 experiences — used for SLO setting

Target: p95 latency under expected peak load must be within SLO before launch.

## Typical Bottlenecks, in Order

1. **Database connection pool** (most common)
   - Each serverless function instance grabs its own pool
   - At 50 concurrent requests × 10 connections = 500 connections; most Postgres plans cap at 100
   - Fix: PgBouncer, Supabase connection pooler, Prisma Accelerate

2. **Missing database index**
   - Query that returns in 2ms on dev (100 rows) takes 800ms on prod (100k rows)
   - Fix: `EXPLAIN ANALYZE` on prod query, add index

3. **N+1 query patterns**
   - Fetching a list of 50 orders, then querying each order's items separately = 51 queries
   - Revealed by load test, not unit test
   - Fix: join or batch fetch

4. **External API calls in critical path**
   - Payment provider, email service, geocoding in the request path
   - One slow external call blocks the entire request
   - Fix: move to background job or add timeout with fallback

5. **Autoscaling lag**
   - Kubernetes/ECS scale events take 30–90 seconds
   - Burst traffic can exhaust existing instances before new ones are ready
   - Fix: pre-warm, increase minimum instances, tune scale-up threshold

## Load Testing Tools

```bash
# k6 — scriptable, modern
k6 run --vus 100 --duration 5m script.js

# hey — simple HTTP load tester
hey -n 10000 -c 100 https://api.example.com/health

# Artillery — YAML-based, good for complex scenarios
artillery run load-test.yml
```

## Minimal k6 Script

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 50 },   // ramp up
    { duration: '5m', target: 100 },  // sustained load
    { duration: '2m', target: 0 },    // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95th percentile under 500ms
    http_req_failed: ['rate<0.01'],    // error rate under 1%
  },
};

export default function () {
  const res = http.get('https://api.example.com/orders');
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(1);
}
```

## Interpreting Results

- **Thresholds breached:** Find the bottleneck before launch; do not negotiate the SLO downward
- **Errors spike at specific VU count:** Connection pool or rate limit ceiling — tune or increase
- **Latency climbs gradually:** Memory leak or cache eviction; profile over longer run
- **Autoscaling didn't help:** Scale events too slow, or bottleneck is DB (doesn't scale with app instances)

## Key Rules
- p95 latency under peak load is the go/no-go metric, not average latency
- Load test on a production-equivalent environment, not dev (different DB size, different connection limits)
- DB connection pool exhaustion is the most common bottleneck in serverless architectures
- Autoscaling must be tested under load — scale events take time and can be too slow
- A load test that finds no problems on the first run usually means the test didn't load high enough
- Build the load test script at feature design time, not the night before launch
