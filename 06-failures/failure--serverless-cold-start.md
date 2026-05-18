# Failure: Serverless Cold Start Latency

A cold start occurs when a serverless function is invoked after its execution environment has been destroyed. The cloud provider must allocate a container, load the runtime, download the function bundle, initialize module-level code, and then finally run the handler. On AWS Lambda (backing Vercel's Node.js runtime), this takes 200–800ms. Users experience it as an unexplained first-request delay.

## Why Cold Starts Happen

Serverless platforms scale to zero. When no traffic hits a function for a period (minutes to hours, depending on the platform), the container is deallocated. The next request pays the full initialization cost. Heavily-trafficked endpoints rarely cold-start; low-traffic endpoints (cron job webhook receivers, rarely-visited API routes) cold-start frequently.

Large function bundles make it worse. Every megabyte of JavaScript the runtime parses and JIT-compiles adds to cold start time. A 10MB bundle has a measurably longer cold start than a 100KB bundle.

## Warming via Cron Ping

A periodic ping keeps the execution environment warm by preventing it from being deallocated:

```ts
// Vercel cron (vercel.json)
{
  "crons": [{ "path": "/api/keep-warm", "schedule": "*/5 * * * *" }]
}

// /api/keep-warm/route.ts
export async function GET() {
  return Response.json({ ok: true });
}
```

This trades a tiny amount of cost (5 invocations/hour) for reduced cold starts. It does not eliminate cold starts — it only reduces the window during which the environment might be deallocated. Under heavy traffic, additional instances still cold-start.

Warming is most useful for: background job receivers, webhook endpoints, auth token refresh routes.

## Edge Runtime: Faster Cold Starts

Vercel's Edge Runtime uses V8 isolates instead of Node.js containers. Cold start overhead drops from 200–800ms to roughly 0–50ms because isolates are cheaper to initialize than full Node.js processes.

```ts
export const runtime = 'edge';
```

Trade-off: Edge Runtime lacks Node.js built-ins (`fs`, `crypto` module, native addons). It is well-suited for: auth checks, routing decisions, response transforms, simple data fetching. It is not suitable for: database clients that require TCP sockets, file system access, or any native module.

Use Edge for the latency-sensitive endpoints where cold starts are most disruptive (auth middleware, user-facing API routes). Keep heavy processing on the Node.js runtime where the richer API surface is necessary.

## Connection Pooling at Module Level

Database connection initialization is expensive — it involves DNS resolution, TCP handshake, TLS negotiation, and authentication. If a connection is established inside the request handler, every cold-started invocation pays this cost (and cold-started invocations are precisely the ones already paying initialization overhead).

```ts
// WRONG — connection established per request
export async function GET() {
  const client = new PrismaClient(); // reconnects on every cold start
  const data = await client.user.findMany();
  return Response.json(data);
}

// RIGHT — connection established at module level, reused across warm invocations
const prisma = new PrismaClient();

export async function GET() {
  const data = await prisma.user.findMany();
  return Response.json(data);
}
```

Module-level initialization runs once per container lifetime. Warm invocations reuse the existing connection — the overhead appears only on cold starts, not every request.

For serverless specifically, use a connection pooler (Supabase Supavisor, PgBouncer, Neon's serverless driver) to avoid exhausting the database's connection limit when many instances cold-start simultaneously.

## Measuring Cold vs. Warm Latency

Vercel Function Logs tag each invocation. Compare first-request latency after a period of no traffic (cold) vs. subsequent requests (warm). The difference is your cold start cost. If it exceeds 500ms, the fixes in this document are worth prioritizing.

Tools: Vercel Function Logs (dashboard), `x-vercel-cache: MISS` header, or Datadog/New Relic timing spans.

## Key Rules

- Module-level initialization (DB clients, SDK clients) runs once per container — always initialize at module scope, not inside handlers.
- Use Vercel cron pings for endpoints where cold start latency is user-visible and traffic is intermittent.
- Reach for Edge Runtime first for latency-sensitive, stateless endpoints — 50ms cold start vs 500ms is a meaningful UX difference.
- Use a connection pooler (Supavisor, Neon serverless) to prevent connection storms when many instances cold-start simultaneously.
- Minimize bundle size — dynamic imports for large, rarely-used modules reduce parse time during initialization.
- Measure before optimizing: verify cold starts are actually the bottleneck before adding complexity.
