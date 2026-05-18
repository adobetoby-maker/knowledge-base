# MCP: Cloudflare Deployment

## Tool Reference

| Tool | Purpose |
|---|---|
| `cloudflare-api:execute` | Run any Cloudflare API call |
| `cloudflare-api:search` | Search Cloudflare API documentation |
| `cloudflare-docs:search_cloudflare_documentation` | Search CF docs |
| `cloudflare-docs:migrate_pages_to_workers_guide` | Migration guide |

## Checking Worker Status

```
cloudflare-api:execute({
  endpoint: "/accounts/{account_id}/workers/services/{service_name}",
  method: "GET"
})

→ Returns: script (the current worker code), bindings, crons, compatibility_date
```

## Listing Workers

```
cloudflare-api:execute({
  endpoint: "/accounts/{account_id}/workers/scripts",
  method: "GET"
})

→ Returns all workers: id, etag, handlers, created_on, modified_on
```

## Deploying via Wrangler (Local)

For language-lens-elite and silver-creek worker deployments:

```bash
# From project directory:
wrangler deploy

# Preview before deploying:
wrangler dev

# Tail logs from production:
wrangler tail

# Check deployment info:
wrangler deployments list
```

## KV Operations via MCP

```
cloudflare-api:execute({
  endpoint: "/accounts/{account_id}/storage/kv/namespaces",
  method: "GET"
})
→ List all KV namespaces and their IDs

cloudflare-api:execute({
  endpoint: "/accounts/{account_id}/storage/kv/namespaces/{namespace_id}/values/{key}",
  method: "GET"
})
→ Read a specific KV value
```

## D1 Database Operations via MCP

```
cloudflare-api:execute({
  endpoint: "/accounts/{account_id}/d1/database",
  method: "GET"
})
→ List all D1 databases

cloudflare-api:execute({
  endpoint: "/accounts/{account_id}/d1/database/{database_id}/query",
  method: "POST",
  body: { sql: "SELECT * FROM items LIMIT 10", params: [] }
})
→ Run SQL against D1
```

## R2 Buckets via MCP

```
cloudflare-api:execute({
  endpoint: "/accounts/{account_id}/r2/buckets",
  method: "GET"
})
→ List R2 buckets

cloudflare-api:execute({
  endpoint: "/accounts/{account_id}/r2/buckets/{bucket_name}/objects",
  method: "GET"
})
→ List objects in a bucket
```

## Cron Trigger Management

```
cloudflare-api:execute({
  endpoint: "/accounts/{account_id}/workers/scripts/{script_name}/schedules",
  method: "GET"
})
→ List cron schedules for a worker

# Update schedule:
cloudflare-api:execute({
  endpoint: "/accounts/{account_id}/workers/scripts/{script_name}/schedules",
  method: "PUT",
  body: [{ cron: "*/30 * * * *" }]
})
```

## Getting Account ID

The `{account_id}` is your Cloudflare account ID. Find it:
1. Via Cloudflare dashboard → right sidebar
2. Or: `wrangler whoami`

## Viewing Worker Logs

```bash
# Real-time log tail (development):
wrangler tail --format pretty

# Filter by status:
wrangler tail --status error
```

For production logs at scale, use Cloudflare's Workers Logpush to send logs to a storage destination (R2, Datadog, etc.).
