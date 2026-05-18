# Failure: Vercel Function Timeout

Vercel serverless functions have hard execution limits: 10 seconds on the Hobby plan, 60 seconds on Pro (configurable up to 300s for Pro/Enterprise). Hitting the limit produces a 504 Gateway Timeout visible to the user. The function is killed mid-execution — any work done is lost unless it was persisted before the deadline.

## Why Functions Time Out

The most common causes: LLM API calls with large outputs, database queries without indexes on large tables, external HTTP calls to slow third-party APIs, and file processing (PDF parsing, image resizing) on large inputs. The timeout is wall-clock time, not CPU time, so waiting on I/O counts fully against the limit.

## Strategy 1: Streaming Responses

Streaming starts the response immediately and sends chunks as they arrive. Vercel measures "time to first byte" separately from total duration — a streaming response that takes 90 seconds to complete can still work on a 60s plan because the connection stays alive and data flows continuously.

```ts
// Next.js App Router — stream an LLM response
export async function POST(req: Request) {
  const stream = await anthropic.messages.stream({ ... });
  return new Response(stream.toReadableStream());
}
```

Use streaming whenever output can be generated incrementally: LLM text, chunked file downloads, server-sent events. Do not use streaming as a workaround for fundamentally unbounded work — it only helps when there's meaningful output to emit throughout the operation.

## Strategy 2: Respond Immediately, Work in Background

Acknowledge the request synchronously, then hand off the real work. The user gets an immediate 202 response; the work continues elsewhere.

Pattern: write a job record to the database in the function (fast), return the job ID to the client, then process it in a background system. The client polls or uses a webhook for the result.

This is the correct pattern for: sending emails after a form submit, processing uploaded files, triggering multi-step AI pipelines, syncing data to external systems.

Tools for the background layer: Vercel's own background functions (`export const maxDuration = 300; export const config = { runtime: 'nodejs' }`), Cloudflare Workers with Durable Objects, Inngest, QStash, Trigger.dev, or a dedicated queue like SQS/BullMQ on a long-running server.

## Strategy 3: Edge Runtime

Edge functions run in Vercel's edge network rather than AWS Lambda. Cold starts are faster (~0ms vs 200–500ms), and there's no hard per-invocation timeout in the same way — but the execution model is different (Web Workers API only, no Node.js built-ins, limited memory).

Use Edge for: low-latency routing, auth middleware, simple transforms, lightweight API responses. Do not use Edge for: file system access, native modules, anything requiring the Node.js runtime.

```ts
export const runtime = 'edge';
```

## Moving Expensive Work to a Queue

The pattern for reliably escaping timeout constraints:

1. Inbound function validates input and writes a job to a queue (fast, < 1s).
2. Returns 202 Accepted with a job ID.
3. A separate worker picks up the job and processes it without time pressure.
4. Result is written back to the database.
5. Client polls `GET /api/jobs/[id]` or receives a webhook when complete.

The queue decouples HTTP latency from processing time. The serverless function never does the slow work — it only enqueues it. This also enables retries without re-hitting the user-facing endpoint.

## Measuring Actual Duration

Vercel's Function Logs (in the dashboard) show execution duration per invocation. Check these before optimizing — often the culprit is one slow database call, not the entire function. A missing index on a 100k-row table can turn a 3ms query into a 12-second one.

## Key Rules

- Streaming buys time for incremental output (LLMs, chunked data) but does not fix unbounded background work.
- For any operation that takes more than 3–4 seconds reliably, design it as a background job from the start.
- Always set `maxDuration` explicitly in `route.ts` to document the expected limit — implicit defaults change across plans.
- Diagnose timeout root cause (Function Logs) before reaching for a queue; often a slow query or missing index is the fix.
- Edge Runtime is not a timeout escape hatch — it has different trade-offs and a restricted API surface.
- Return a job ID and poll URL in the 202 response so the client can track progress without re-submitting.
