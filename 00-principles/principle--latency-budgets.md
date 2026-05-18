# Principle: Latency Budgets

## Overview
User-perceived latency is the sum of every hop between a user action and a visible result. If you optimize the database query but ignore the three serial API calls each adding 100ms, you didn't improve the user experience. Latency budgets make this concrete: allocate a time budget to each component in the request path and hold each component accountable to its budget. You cannot compensate for an over-budget component by optimizing other components — you must fix the over-budget one.

## Key Points

### Decomposing a Request

A typical web request for a page load:
```
User action → DNS lookup (20ms) → TLS handshake (50ms) → Request in flight (30ms)
→ Server processing (10ms) → DB query (40ms) → Template render (5ms)
→ Response in flight (30ms) → Browser parse/layout (15ms)

Total: ~200ms (target: < 200ms for "instant" feel)
```

Each hop has an owner:
- DNS/TLS → CDN/infrastructure team
- Network → geography, CDN placement
- Server processing → application code
- DB query → query optimization, indexes, connection pooling
- Browser → JavaScript bundle size, render-blocking resources

### Setting Budgets

Rule of thumb thresholds for web:
```
< 100ms  → feels instantaneous
100–300ms → feels responsive  
300–1000ms → noticeable delay, but tolerable
> 1000ms  → frustrating; user questions if it worked
> 3000ms  → most users abandon
```

For API responses (not page loads):
```
P50 < 50ms   → good
P95 < 200ms  → acceptable
P99 < 500ms  → needs investigation
P99 > 1000ms → systemic problem
```

### Where Budgets Are Commonly Blown

**N+1 queries:**
```ts
// 1 query to get posts + N queries for each post's author = O(N) DB calls
const posts = await db.post.findMany();
for (const post of posts) {
  post.author = await db.user.findUnique({ where: { id: post.authorId } }); // N calls
}

// Fix: eager load in one query
const posts = await db.post.findMany({ include: { author: true } });
```

**Serial calls that could be parallel:**
```ts
// Bad: 300ms total (sequential)
const user = await getUser(id);         // 100ms
const posts = await getPosts(id);       // 100ms
const settings = await getSettings(id); // 100ms

// Good: 100ms total (parallel)
const [user, posts, settings] = await Promise.all([
  getUser(id),
  getPosts(id),
  getSettings(id),
]);
```

**Missing indexes:**
A query scanning 1M rows vs. one using an index: 2000ms vs. 3ms. Profile queries with `EXPLAIN ANALYZE` before assuming application code is the bottleneck.

### Budget Allocation Example

For a product page (target: 300ms to first meaningful content):
```
CDN cache hit:           0ms  (cache HIT path)
CDN to origin:          20ms
App startup/routing:    10ms
DB: product query:      30ms  (budget allocation)
DB: reviews query:      20ms  (budget allocation — can be deferred)
DB: inventory query:    15ms  (budget allocation)
Response serialization:  5ms
Total server:           ~100ms

Network (CDN to user):   50ms (geography-dependent)
Browser first paint:     60ms
Browser interactive:     90ms

Total: ~300ms
```
If DB: product query is consistently 80ms instead of 30ms, the budget is broken — optimize the query.

### Measuring, Not Guessing
Budget allocations must be validated with real measurements:
```ts
// Instrument spans in your application
const span = tracer.startSpan('db.product.query');
const product = await db.product.findUnique({ where: { id } });
span.finish();
```

Use distributed tracing (OpenTelemetry, Datadog, Jaeger) to see actual time spent in each component across a full request trace.

## Key Rules
- Define the total latency target first (e.g., 300ms P95), then allocate budget to each component
- Measure actual latency per component with instrumentation — don't estimate
- Serial I/O that can be parallelized is the most common fixable latency problem
- N+1 query patterns often account for 10–100x unnecessary DB load — always check with query logging
- You cannot compensate for a slow DB query by making the app layer faster
- P99 latency matters: the slowest 1% of users often represents your most engaged users (more data, longer history)
- Latency and throughput are related but different: optimizing one can degrade the other (e.g., aggressive caching reduces latency but increases memory pressure under load)
