# Disambig: Serverless vs Containers

## Overview
Serverless (Lambda, Cloudflare Workers, Vercel Functions) and containers (ECS, Kubernetes, Cloud Run) are not competing technologies — they serve different workload profiles. The decision hinges on traffic patterns, execution duration, runtime requirements, and how much infrastructure management the team wants to own. Most modern applications benefit from a hybrid: serverless for HTTP APIs and background tasks, containers for long-running or stateful services.

## Implementation / Key Points

### Serverless (AWS Lambda / Vercel Functions / Cloudflare Workers)
```ts
// Lambda handler — runs on each invocation, then terminates
export const handler = async (event: APIGatewayProxyEvent) => {
  const body = JSON.parse(event.body ?? '{}');
  const result = await processRequest(body);
  return { statusCode: 200, body: JSON.stringify(result) };
};
// Cold start: ~100ms (Node.js) to ~5ms (Cloudflare Workers edge)
// Max duration: Lambda = 15 min; Vercel Functions = 60s; Workers = 30s CPU
// Memory: Lambda = up to 10GB; Workers = 128MB
```

### Containers (Docker on ECS / Kubernetes / Cloud Run)
```dockerfile
# Dockerfile — persistent process, always running
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```
The process starts once and handles many requests. No cold start per request. Full Node.js API available.

### Comparison

| | Serverless | Containers |
|---|---|---|
| Pricing model | Per request + duration | Per hour (running or idle) |
| Scale to zero | Yes — cost = $0 at idle | No (unless Cloud Run) |
| Cold start | Yes (50ms–2s) | No (warm process) |
| Max duration | 15–60 min (Lambda) | Unlimited |
| Stateful | No (ephemeral filesystem) | Yes (volumes) |
| WebSockets | No (Lambda); Yes (Workers Durable Objects) | Yes |
| Node.js APIs | Lambda: full; Workers: subset | Full |
| Ops complexity | Low (no infra to manage) | High (k8s) to Medium (ECS) |
| Vendor lock-in | High (Lambda) to Low (Workers) | Medium |

### Cold Start Mitigation (Serverless)
```ts
// Keep Lambda warm via provisioned concurrency or periodic pings
// Minimize bundle size — cold start time proportional to code size
// Connection pool initialized outside handler (survives warm invocations)

// ✓ Outside handler (initialized once, reused across warm invocations)
const dbPool = new Pool({ connectionString: process.env.DATABASE_URL });

// ✗ Inside handler (re-initialized on every invocation)
export const handler = async () => {
  const db = new Pool({ connectionString: process.env.DATABASE_URL }); // bad
};
```

### When to Use Serverless
- Variable or spiky traffic (event-driven, webhook handlers, cron jobs)
- APIs that need to scale to zero (cost optimization)
- Edge routing, geo-proxying, authentication middleware
- Simple CRUD APIs with fast, bounded execution time
- Event processors (SQS, S3 triggers, SNS)

### When to Use Containers
- Long-running processes (video transcoding, ML inference, data exports)
- Persistent TCP connections (WebSockets, gRPC streams)
- Complex runtimes (Python with C extensions, Java heap tuning)
- Stateful workloads (session state in memory, temp files)
- Consistent, predictable traffic (containers are cheaper at sustained high load)

### Hybrid Pattern (Common)
```
User HTTP request → Serverless (Next.js/Vercel)
                  → Queues background work → Container (ECS) for long-running processing
                  → Reads DB → Serverless handles response
```

## Key Rules
- Serverless default for HTTP APIs, webhooks, background jobs with bounded execution time.
- Containers required for WebSockets, stateful processes, execution > 15 minutes, or full Node.js runtime.
- Initialize external connections (DB, Redis) outside the Lambda handler — they survive warm invocations.
- Serverless is cheaper at low/variable traffic; containers are cheaper at sustained high load.
- Cloud Run / Fly.io bridges the gap: containerized workloads that scale to zero.
- Cold starts are a real cost — minimize bundle size and use provisioned concurrency for latency-sensitive paths.
