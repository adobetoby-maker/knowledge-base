# Failure: Cloudflare Workers Fetch Behavior

## Overview
Cloudflare Workers run in the V8 isolate runtime, not Node.js. The `fetch()` API is available but behaves differently from Node fetch: no `localhost` access, no relative URLs, no module-scope async, and fire-and-forget promises must be wrapped with `ctx.waitUntil()` or they're killed when the response is sent. Nested fetch to the same Worker URL creates a new Worker invocation — this has latency and cost implications.

## No Localhost, No Relative URLs

```ts
// BAD — Workers have no concept of localhost
const res = await fetch('http://localhost:3000/api/data')
// Error: getaddrinfo ENOTFOUND localhost

// BAD — relative URLs don't work
const res = await fetch('/api/internal')
// Error: Only absolute URLs are supported

// GOOD — always use full absolute URLs
const res = await fetch('https://your-api.example.com/api/data')

// GOOD — for internal service-to-service within Cloudflare
const res = await fetch('https://other-worker.your-subdomain.workers.dev/api')
```

For accessing bound services (KV, D1, R2), use the bindings directly — not fetch:

```ts
// GOOD — use bindings for Cloudflare services
const value = await env.MY_KV.get('key')
const db = env.DB  // D1 binding
```

## `ctx.waitUntil()` for Fire-and-Forget

When you send a Response, the Worker isolate is eligible for shutdown. Any promises that aren't awaited will be killed.

```ts
// BAD — analytics fetch may be killed before completing
export default {
  async fetch(request, env, ctx) {
    const response = buildResponse()
    fetch('https://analytics.example.com/event', { method: 'POST', body: '...' })  // may not complete!
    return response
  }
}

// GOOD — ctx.waitUntil() keeps the isolate alive until the promise resolves
export default {
  async fetch(request, env, ctx) {
    const response = buildResponse()
    ctx.waitUntil(
      fetch('https://analytics.example.com/event', { method: 'POST', body: '...' })
    )
    return response  // returned immediately
  }
}
```

`ctx.waitUntil()` tells Cloudflare: "keep this Worker alive until this promise settles, even after sending the response."

## No Async at Module Scope

```ts
// BAD — top-level await not allowed in Workers
const config = await fetch('https://config.example.com').then(r => r.json())

export default {
  async fetch(request) {
    return new Response(config.message)
  }
}

// GOOD — initialize in the handler or use lazy initialization
let config: Config | null = null

export default {
  async fetch(request, env) {
    if (!config) {
      config = await fetch('https://config.example.com').then(r => r.json())
    }
    return new Response(config.message)
  }
}
```

Better: store config in KV or D1 and read it per-request, or bake it into the Worker bundle at deploy time.

## Nested Fetch to Same Worker (Avoid)

```ts
// Worker A fetching its own URL creates a second Worker invocation
// This works but has latency (new cold start possible) and costs double
export default {
  async fetch(request, env) {
    if (request.url.endsWith('/api/sub')) {
      return handleSubRequest(request, env)
    }

    // BAD — fetch to self
    const sub = await fetch(new URL('/api/sub', request.url))
    const data = await sub.json()
    return Response.json({ data })
  }
}

// GOOD — call the handler function directly
export default {
  async fetch(request, env) {
    if (request.url.endsWith('/api/sub')) {
      return handleSubRequest(request, env)
    }

    const subResponse = await handleSubRequest(new Request(new URL('/api/sub', request.url)), env)
    const data = await subResponse.json()
    return Response.json({ data })
  }
}
```

For complex Worker-to-Worker communication, use Durable Objects or Service Bindings.

## Request Body Can Only Be Read Once

```ts
// BAD — body consumed before the handler reads it
export default {
  async fetch(request, env) {
    await logRequest(request)  // reads request.body
    const body = await request.json()  // Error: body already consumed
    ...
  }
}

// GOOD — clone before reading
async function logRequest(request: Request) {
  const clone = request.clone()
  const body = await clone.text()
  console.log('Request body:', body)
}

export default {
  async fetch(request, env) {
    await logRequest(request)  // reads clone
    const body = await request.json()  // reads original — fine
    ...
  }
}
```

## Key Rules
- Always use absolute URLs in `fetch()` — no `localhost`, no relative paths
- Wrap fire-and-forget operations in `ctx.waitUntil()` — not plain unresolved promises
- No top-level `await` — initialize lazily in handlers or use Cloudflare bindings
- Request body can only be consumed once — clone with `request.clone()` before multiple reads
- Self-fetch creates a new Worker invocation — call functions directly instead
- `env` bindings (KV, D1, R2, Queues) are the correct way to access Cloudflare services, not fetch
