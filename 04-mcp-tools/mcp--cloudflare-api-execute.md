# MCP Tool: cloudflare / cloudflare-api execute

**Plugin:** `plugin:cloudflare:cloudflare-api`
**Tool name:** `mcp__plugin_cloudflare_cloudflare-api__execute`
**What it does:** Calls any Cloudflare REST API endpoint. Covers Workers, D1, KV, R2, Pages, DNS, Analytics — everything not in the bindings/builds/observability sub-tools.

## Parameters
```json
{
  "path": "string (required) — API path after base URL, e.g. '/accounts/{id}/workers/scripts'",
  "method": "GET | POST | PUT | PATCH | DELETE (default GET)",
  "body": "object (optional) — request body for POST/PUT/PATCH"
}
```

## Common Operations

### List Workers
```javascript
mcp__plugin_cloudflare_cloudflare-api__execute({
  path: "/accounts/{ACCOUNT_ID}/workers/scripts"
})
```

### Deploy Worker
```javascript
mcp__plugin_cloudflare_cloudflare-api__execute({
  path: "/accounts/{ACCOUNT_ID}/workers/scripts/my-worker",
  method: "PUT",
  body: { script: "...worker code..." }
})
```

### List D1 Databases
```javascript
mcp__plugin_cloudflare_cloudflare-api__execute({
  path: "/accounts/{ACCOUNT_ID}/d1/database"
})
```

### Query D1
```javascript
mcp__plugin_cloudflare_cloudflare-api__execute({
  path: "/accounts/{ACCOUNT_ID}/d1/database/{DATABASE_ID}/query",
  method: "POST",
  body: { sql: "SELECT * FROM users LIMIT 10" }
})
```

### KV Operations
```javascript
// List KV namespaces
mcp__plugin_cloudflare_cloudflare-api__execute({
  path: "/accounts/{ACCOUNT_ID}/storage/kv/namespaces"
})

// Write a value
mcp__plugin_cloudflare_cloudflare-api__execute({
  path: "/accounts/{ACCOUNT_ID}/storage/kv/namespaces/{NS_ID}/values/my-key",
  method: "PUT",
  body: { value: "my-value", expiration_ttl: 3600 }
})
```

### Purge Cache
```javascript
mcp__plugin_cloudflare_cloudflare-api__execute({
  path: "/zones/{ZONE_ID}/purge_cache",
  method: "POST",
  body: { purge_everything: true }
})
```

## Finding Account/Zone IDs
```javascript
// Get account ID
mcp__plugin_cloudflare_cloudflare-api__execute({ path: "/accounts" })

// Get zone ID for a domain
mcp__plugin_cloudflare_cloudflare-api__execute({ path: "/zones?name=yourdomain.com" })
```

## Search Tool First
For finding the right API path, search docs first:
```javascript
mcp__plugin_cloudflare_cloudflare-api__search({ query: "workers D1 query" })
```

## Preferred Alternative for Workers
The `cloudflare-bindings` MCP handles Workers bindings with auth flows.
Use `cloudflare-api execute` when you need raw REST API access not covered by other Cloudflare MCP tools.
