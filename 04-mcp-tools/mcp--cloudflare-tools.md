# MCP: Cloudflare Tools

## Overview
The Cloudflare MCP tools split into two concerns: `cloudflare-api execute` for live operations against your account (Workers, KV, R2, D1), and `cloudflare-docs search` for finding current API specs before you write a request. Always search the docs first—the Cloudflare API surface changes frequently and training data goes stale. Wrangler CLI remains the right tool for local development and iteration; MCP is for remote production operations from within a session.

## Core Tools

| Tool | Purpose |
|---|---|
| `cloudflare-api execute` | Call any Cloudflare REST API endpoint |
| `cloudflare-api search` | Find API endpoints by keyword (alternative to docs) |
| `cloudflare-docs search` | Search official Cloudflare documentation |

## Pattern: Search Docs Before Execute
```
1. cloudflare-docs search("KV namespace list keys")
   → confirms endpoint: GET /accounts/{account_id}/storage/kv/namespaces/{namespace_id}/keys
   → confirms parameters: limit, cursor, prefix

2. cloudflare-api execute({
     method: "GET",
     path: "/accounts/abc123/storage/kv/namespaces/ns_id/keys",
     params: { limit: 100, prefix: "user:" }
   })
```

## Common Operation Patterns

### Workers — List and Get
```
cloudflare-api execute({
  method: "GET",
  path: "/accounts/{account_id}/workers/scripts"
})
→ list all deployed scripts

cloudflare-api execute({
  method: "GET",
  path: "/accounts/{account_id}/workers/scripts/{script_name}"
})
→ get script metadata (bindings, cron triggers, etc.)
```

### KV — Read and Write
```
// Read a value
cloudflare-api execute({
  method: "GET",
  path: "/accounts/{account_id}/storage/kv/namespaces/{ns_id}/values/{key}"
})

// Write a value
cloudflare-api execute({
  method: "PUT",
  path: "/accounts/{account_id}/storage/kv/namespaces/{ns_id}/values/{key}",
  body: "value-string",
  params: { expiration_ttl: 3600 }
})
```

### R2 — List Buckets and Objects
```
cloudflare-api execute({
  method: "GET",
  path: "/accounts/{account_id}/r2/buckets"
})

cloudflare-api execute({
  method: "GET",
  path: "/accounts/{account_id}/r2/buckets/{bucket_name}/objects",
  params: { limit: 100, prefix: "uploads/" }
})
```

### D1 — Query Database
```
cloudflare-api execute({
  method: "POST",
  path: "/accounts/{account_id}/d1/database/{db_id}/query",
  body: {
    sql: "SELECT * FROM users WHERE created_at > ?",
    params: ["2026-01-01"]
  }
})
```

## Local Development vs MCP
```
Local dev (use Wrangler CLI):
  wrangler dev                    # local Worker with hot reload
  wrangler kv:key put key value   # KV operations on local emulator
  wrangler d1 execute db --local  # D1 local dev

Remote prod operations (use MCP):
  - Inspecting production KV values
  - Checking Worker metadata and bindings
  - Reading D1 production data
  - Triggering Worker deployments
  - Managing R2 bucket contents
```

## Key Rules
- **Search docs before execute** — the API path format changes; don't guess from memory.
- **Wrangler for local dev** — MCP operate against production; use wrangler for iteration.
- **Account ID in every path** — Cloudflare API paths always include `{account_id}`; find it in the dashboard or `cloudflare-api execute({ method: "GET", path: "/accounts" })`.
- **D1 queries are synchronous** — unlike Workers analytics which are async; results come back immediately.
- **Never use MCP to deploy from scratch** — use `wrangler deploy` for first-time Worker deploys; MCP for inspection and minor operations.
