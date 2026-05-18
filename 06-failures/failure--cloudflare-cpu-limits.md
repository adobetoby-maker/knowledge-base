# Cloudflare Workers CPU Limits

## The Distinction: CPU Time vs Wall Clock Time

Cloudflare Workers have a **CPU time limit**, not a wall clock time limit.

- **Wall clock time** — elapsed real time from start to finish (including time waiting for network/DB responses)
- **CPU time** — time the Worker is actually executing JavaScript (not counting await pauses)

A Worker can wait 30 seconds for a Supabase query (wall clock) but only use 10ms of CPU during that wait. The CPU limit applies to the active execution.

Limits on free plan: 10ms CPU time per invocation. Paid plan (Workers Paid): 30 seconds CPU time. Workers Unbound: up to 15 minutes.

## Symptoms

```
Error 1101: Worker hit CPU limit
Worker exceeded CPU time limit
```

This appears when the Worker executes too much synchronous JavaScript — not when it's waiting for network responses.

## What Consumes CPU

**High CPU operations:**
- JSON parsing/stringifying large objects
- Cryptographic operations (bcrypt, heavy hashing)
- Complex data transformations (sorting large arrays, regex on large strings)
- Compression/decompression
- Image processing (WebP conversion, resizing) — use Cloudflare Images API instead
- Loop-heavy algorithms on large datasets

**Low CPU operations (mostly waiting):**
- `await fetch(url)` — network request, CPU pauses during wait
- `await env.KV.get(key)` — KV lookup, CPU pauses during wait
- `await env.DB.prepare(sql).run()` — D1 query, CPU pauses
- `await env.QUEUE.send(message)` — queue send

## Diagnosis

Add timing measurements:
```typescript
export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const times: Record<string, number> = {}
    
    let start = Date.now()
    const data = await env.DB.prepare('SELECT * FROM large_table').all()
    times.dbQuery = Date.now() - start
    
    start = Date.now()
    const processed = data.results.map(row => transformRow(row))  // CPU-heavy
    times.transform = Date.now() - start
    
    console.log('Timing:', JSON.stringify(times))
    // If transform >> dbQuery, the CPU-heavy part is the transform
    
    return Response.json(processed)
  }
}
```

## Solutions

**Move CPU-heavy work off the Worker:**

```typescript
// Instead of image processing in Worker → use Cloudflare Images
// Instead of PDF generation → use a dedicated service
// Instead of complex ML → use AI binding (Workers AI)

// Workers AI binding — offloads to Cloudflare's GPU infrastructure
const output = await env.AI.run('@cf/meta/llama-3-8b-instruct', {
  messages: [{ role: 'user', content: prompt }]
})
```

**Chunk large data processing:**
```typescript
// PROBLEMATIC — processes 10,000 rows synchronously
const results = rows.map(row => heavyTransform(row))

// BETTER — chunk with yielding (doesn't help much in Workers, but reduces peak CPU burst)
const CHUNK_SIZE = 100
const results = []
for (let i = 0; i < rows.length; i += CHUNK_SIZE) {
  const chunk = rows.slice(i, i + CHUNK_SIZE)
  results.push(...chunk.map(row => heavyTransform(row)))
  // Can't actually yield CPU in Workers — consider moving to a Queue
}
```

**Use Queues for CPU-intensive work:**
```typescript
// Worker receives request, queues heavy work, returns immediately
export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const body = await req.json()
    await env.PROCESSING_QUEUE.send({ jobId: crypto.randomUUID(), data: body })
    return Response.json({ queued: true })
  }
}

// Queue consumer Worker processes asynchronously with more CPU budget
export default {
  async queue(batch: MessageBatch<ProcessingJob>, env: Env): Promise<void> {
    for (const message of batch.messages) {
      await processHeavyJob(message.body, env)
      message.ack()
    }
  }
}
```

## For opennextjs/cloudflare

Next.js apps running on Cloudflare Workers via `@opennextjs/cloudflare` have the same CPU limits. Long-running Server Actions or API routes can hit limits.

Signs: 1101 errors on routes that do data processing, complex page renders, or large JSON operations.

Fix: Move heavy processing to Route Handlers that use streaming or queues, reduce the amount of data processed per request.
