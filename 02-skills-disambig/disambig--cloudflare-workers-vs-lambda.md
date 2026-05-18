# Disambig: Cloudflare Workers vs AWS Lambda

## Overview
Cloudflare Workers and AWS Lambda are both serverless compute platforms, but they operate on entirely different execution models. Workers use V8 isolates—ultra-lightweight, no Node.js, near-zero cold start, running at the network edge close to users. Lambda uses traditional VMs with a full Node.js/Python/Go runtime, allowing more memory, longer execution, and access to the full AWS ecosystem. The choice is primarily about latency requirements vs runtime capabilities.

## Comparison

| Property | Cloudflare Workers | AWS Lambda |
|---|---|---|
| Runtime | V8 isolate (no Node.js) | Node.js, Python, Go, Java, Ruby, .NET |
| Cold start | Sub-millisecond | 100ms–3s (depends on runtime/size) |
| Execution location | Edge — 300+ locations | Regional — deploy to specific region |
| Max RAM | 128 MB | 128 MB – 10 GB |
| Max CPU time | 50ms (free), 30s (paid) | Up to 15 minutes |
| Node.js APIs | Not available (Web APIs only) | Full Node.js |
| npm packages | Limited (Web API compatible only) | Any npm package |
| Environment | Web APIs (fetch, crypto, streams) | Node.js + AWS SDK |
| Filesystem | None (Workers KV, R2 for storage) | /tmp (512 MB ephemeral) |
| Pricing | Per request + CPU time | Per request + GB-seconds |
| Network | Cloudflare network | AWS VPC, security groups |
| Database access | Cloudflare D1, KV, R2, Hyperdrive | RDS, DynamoDB, S3 (native) |
| Secrets | Wrangler secrets / env vars | AWS Secrets Manager, SSM, env vars |

## When to Use Cloudflare Workers

```
Low-latency edge logic
→ Workers run <50ms from any user; Lambda runs in one region

Request/response transformation
→ Modify headers, rewrite URLs, A/B test routing — all at the edge

Static API with simple data access (KV, D1)
→ Workers + KV/D1 handle most CRUD workloads with sub-10ms response

Authentication middleware
→ JWT verification at edge before request hits origin; no added latency

Rate limiting and bot detection
→ Workers can inspect and block requests before they reach your server

Image/text transformation at delivery
→ Resize, format-convert, or compress content at the CDN layer

Globally distributed applications
→ Workers auto-replicate to all 300+ edge locations; no region selection needed
```

## When to Use Lambda

```
Long-running operations (>30 seconds)
→ Lambda supports up to 15 minutes; Workers time out at 30s

High-memory workloads
→ Video processing, ML inference, large file parsing — need 1-10 GB RAM

Node.js-specific packages
→ Sharp, Puppeteer, native addons require Node.js; Workers can't run them

AWS ecosystem integration
→ SQS, SNS, S3 triggers, RDS, DynamoDB — Lambda integrates natively

Complex business logic with many dependencies
→ Large npm dependency tree; Workers bundle size limit (1-10 MB compressed)

Existing Lambda infrastructure
→ Migrating working Lambda functions to Workers introduces risk with limited benefit
```

## The V8 Isolate Constraint

```
Workers run in V8 isolates, not Node.js. This means:

Available:
  fetch(), crypto.subtle, URL, TextEncoder, ReadableStream, Response, Request
  WebSockets (Durable Objects), Cache API, HTMLRewriter

NOT available:
  fs, path, os, net, child_process, Buffer (use Uint8Array instead)
  Most native Node.js modules
  process.env is replaced by env bindings

Packages that work in Workers:
  zod, date-fns, nanoid, jose (JWT), hono, itty-router
  Most pure JS packages without Node.js dependencies

Packages that DON'T work:
  sharp (native bindings), bcrypt (native), pg (net module), axios (Node.js http)
```

## Hybrid Architecture

```
Common pattern: Workers at edge + Lambda for heavy processing

Browser → Cloudflare Worker (auth check, rate limit, routing)
        → Lambda (complex business logic, DB writes, third-party API calls)
        → S3 / RDS (storage)

Workers handle: auth, caching, routing, static responses
Lambda handles: anything requiring Node.js, long execution, or high memory
```

## Key Rules
- **Workers for latency-sensitive, stateless operations** — auth checks, routing, simple transforms, edge caching.
- **Lambda for anything requiring Node.js** — native modules, long execution, high memory, or AWS ecosystem.
- **Workers cannot run npm packages with Node.js dependencies** — test compatibility before committing to Workers.
- **Workers cold start is effectively zero** — V8 isolates spin up in <1ms; Lambda cold starts are a real UX problem.
- **Workers are global by default** — you don't choose a region; Lambda requires explicit multi-region deployment.
- **Use Hyperdrive for DB connections from Workers** — direct TCP connections to Postgres aren't supported in Workers; Hyperdrive proxies them.
