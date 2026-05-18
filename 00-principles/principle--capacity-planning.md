# Principle: Capacity Planning

## Overview
Systems hit their limits in ways that engineers do not expect. The bottleneck is rarely where intuition points. CPU and memory are visible, easy to scale, and well-monitored. Database connections are invisible until they're exhausted. File descriptor limits, connection pool exhaustion, and queue depth limits cause complete outages at traffic levels that look modest on a CPU graph. Capacity planning means modeling traffic growth, identifying which limit you hit first, and resolving it before users find it.

## Key Points

### Database Connections Are Often the First Bottleneck
PostgreSQL default max connections: 100. With connection pooling default settings, this is easily exhausted under moderate load:

```
100 connections ÷ 10 Node.js instances = 10 connections per instance
10 connections per instance × 4 DB operations per request = 2.5 req/sec per instance
10 instances total = 25 req/sec before connection exhaustion
```

Solutions:
- **PgBouncer / Supabase Pooler:** transaction-mode pooling multiplexes thousands of app connections onto dozens of DB connections
- **Connection limits per service:** set explicit pool limits; better to queue than to error
- **Serverless:** if using Neon or Supabase, their poolers are essential — not optional

### Traffic Growth Modeling
```
Current: 1,000 req/day
Growth: 2x every 6 months

Month 0:  1,000 req/day
Month 6:  2,000 req/day
Month 12: 4,000 req/day
Month 18: 8,000 req/day  ← ~10x original
Month 24: 16,000 req/day ← ~16x original
```

This is the minimum planning horizon for infrastructure decisions. A DB schema designed for 1,000 rows that now has 100M rows behaves very differently — queries that took 3ms now take 3 seconds.

### Identify Your Limiting Resource
For each service, the bottleneck is one of:
- **DB connections** (most common for web apps)
- **DB query throughput / IOPS** (read-heavy loads without caching)
- **Memory** (in-memory caches, large query results held in RAM)
- **CPU** (compute-heavy: image processing, encryption, serialization)
- **Network I/O** (video streaming, large file uploads/downloads)
- **Third-party API rate limits** (Stripe, Twilio, SendGrid have per-second limits)

The limiting resource changes as you scale — you resolve one bottleneck and hit the next.

### Load Testing Before Production
Know your limits before users find them:
```bash
# k6 load test: ramp to 1000 concurrent users
k6 run --vus 1000 --duration 30s load-test.js
```

Run load tests against staging:
1. Identify at what load the P95 latency starts degrading
2. Identify at what load errors start appearing
3. Document: "this service handles N req/sec before degradation"
4. Compare to projected traffic in 6/12/18 months

### Stateless vs. Stateful Scaling

**Stateless services scale horizontally:**
```
Load balancer → [App instance 1]
              → [App instance 2]  ← just add more
              → [App instance 3]
```
Any instance can handle any request. Scaling is linear. Session state in cookies or JWTs, not in memory.

**Stateful services need different strategy:**
- Database: vertical scaling first, then read replicas, then sharding (complex)
- Session stores (Redis): sentinel/cluster for HA, but still a single logical system
- Message queues: topic partitioning, consumer groups

### Resource Limits That Surprise Engineers
- **File descriptors:** Each open socket/file = 1 fd. Default limit: 1024. Under load with many DB connections + HTTP connections + log files, this is hit.
- **OS thread limits:** Node.js is single-threaded but uses worker threads for I/O; thread pool default is 4 (UV_THREADPOOL_SIZE)
- **DNS resolution:** High-scale apps resolve thousands of hostnames/sec; OS-level DNS resolver can become a bottleneck
- **SSL certificate renewal:** Let's Encrypt rate limits: 50 certificates per domain per week

### Planning Checklist

Before launch, answer:
- What is the expected peak req/sec?
- What is our measured max capacity (from load tests)?
- What is the margin (max ÷ expected peak)? Target: ≥ 3x headroom
- What breaks first when we exceed capacity?
- What is the scale-up procedure for each limiting resource?

## Key Rules
- DB connections are the first bottleneck for most web apps — always use connection pooling
- 2x traffic every 6 months = 10x in 18 months; plan infrastructure at 18-month horizon
- Stateless application servers scale horizontally; stateful services (DB) need vertical scaling or sharding
- Load test before launch, not after the first traffic spike
- Know your third-party API rate limits; exceeded limits cause cascading failures
- Capacity headroom target: 3x current peak to absorb growth and traffic spikes
- Capacity planning is not a one-time exercise; revisit quarterly as traffic patterns change
