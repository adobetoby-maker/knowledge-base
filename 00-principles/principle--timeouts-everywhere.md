# Principle: Timeouts Everywhere

## The Default Is Disaster

Most HTTP clients, database drivers, and network libraries have no default timeout or a very long one (minutes). This means a slow dependency — a database that's overloaded, a third-party API that's hung, a DNS resolver that's wedged — will hold your server's connection open indefinitely. If enough requests pile up waiting on that slow call, you run out of connection pool slots, thread pool slots, or memory. Your service stops responding. The slow upstream takes your service down with it.

This is called a **cascading failure**. The original problem was a slow database. The observable failure is that your entire service is down.

## Timeout at Each Layer

There are multiple places where a slow call can stall:

1. **DNS resolution** — looking up the hostname. Can hang for 30+ seconds if the resolver is unreachable.
2. **TCP connection** — the three-way handshake. Hangs if the host is unreachable (not refused — just silent).
3. **TLS handshake** — additional round trips before HTTP even starts.
4. **Request/response** — the server accepted the connection but hasn't sent a response. Infinitely long queries live here.
5. **Read** — the server started sending but stops mid-stream.

Most HTTP libraries have separate settings for connection timeout vs request/read timeout. Set both.

```typescript
// Node.js fetch with timeout via AbortController
async function fetchWithTimeout(url: string, ms = 5000): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  try {
    return await fetch(url, { signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

// Postgres (pg library) — connection timeout
const pool = new Pool({
  connectionTimeoutMillis: 3000,  // fail fast if can't connect
  idleTimeoutMillis: 10000,       // release idle connections
  statement_timeout: 30000,       // kill runaway queries at the DB level
});
```

## Circuit Breaker vs Timeout

A timeout handles a single slow request. A **circuit breaker** handles a dependency that is consistently failing. When enough requests timeout within a window, the circuit opens and subsequent requests fail immediately (without waiting for the timeout), giving the dependency time to recover.

Use both together:
- **Timeout** — the max you're willing to wait on any single request.
- **Circuit breaker** — stops sending requests after repeated failures, prevents timeout backlog.

Without a circuit breaker, if your timeout is 10 seconds and 50 requests per second pile up waiting, you have 500 concurrent waiting requests in 10 seconds. With a circuit breaker, after the first 5 failures, new requests fail immediately.

## What Happens When You Miss One Timeout

The failure mode is always the same: requests accumulate. Every blocked thread or open connection represents memory and resources. The cascade happens in stages:

1. The slow dependency starts hanging.
2. Requests that hit it start piling up (waiting for the timeout you didn't set).
3. Your connection pool fills. New requests can't get a connection.
4. Your service's response time climbs — even requests that don't touch the slow dependency start queuing.
5. Health checks start failing. The load balancer marks your service unhealthy.
6. More traffic hits surviving instances. They cascade too.

One missing timeout, one slow vendor API, and you've taken down a service that had nothing to do with that vendor.

## Setting Timeout Values

Timeout values should match the operation's SLA, not be set arbitrarily:

- **Read DB lookup**: 500ms–2s
- **Write DB operation**: 2s–5s
- **Internal service call**: 1s–3s
- **Third-party API**: 5s–10s (check their SLA)
- **AI/LLM API call**: 30s–120s (streaming)
- **Background job**: whatever makes sense, but always have one

Err toward shorter. A fast failure that returns an error is better than a slow failure that blocks.

## Key Rules

- **Every external call needs a timeout** — no exceptions; no "it's internal so it's fine."
- **Set both connect timeout and read timeout** — they cover different failure modes.
- **Pair timeouts with circuit breakers** for dependencies you care about.
- **Use `statement_timeout` at the DB level too** — a runaway query should fail at the DB, not just on the client.
- **Log when timeouts fire** — treat each one as signal about dependency health.
- **Test timeout behavior explicitly** — use `toxiproxy` or similar to simulate slow dependencies in tests.
- **Default to shorter timeouts** — you can always increase them; a missing timeout causes outages.
