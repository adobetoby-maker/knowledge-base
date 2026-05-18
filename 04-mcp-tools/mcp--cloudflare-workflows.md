# MCP: Cloudflare — Common Workflows

## Tool Reference

```
mcp__plugin_cloudflare_cloudflare-api__execute(operation, params)
mcp__plugin_cloudflare_cloudflare-api__search(query)
mcp__plugin_cloudflare_cloudflare-docs__search_cloudflare_documentation(query)
```

The Cloudflare MCP server wraps the Cloudflare API. Operations map directly to API endpoints.

## Common Operations

### List Workers
```
execute("workers.scripts.list", { account_id: "..." })
```

### Get Worker Details
```
execute("workers.scripts.get", { account_id: "...", script_name: "silvercreek-dispatch" })
```

### List KV Namespaces
```
execute("kv.namespaces.list", { account_id: "..." })
```

### Get KV Value (for debugging)
```
execute("kv.namespaces.keys.list", { account_id: "...", namespace_id: "..." })
execute("kv.namespaces.values.get", { account_id: "...", namespace_id: "...", key_name: "session:user123" })
```

### List D1 Databases
```
execute("d1.databases.list", { account_id: "..." })
```

### Query D1
```
execute("d1.databases.query", {
  account_id: "...",
  database_id: "...",
  sql: "SELECT COUNT(*) FROM users",
  params: []
})
```

### List R2 Buckets
```
execute("r2.buckets.list", { account_id: "..." })
```

## Zones and Domains

### List Zones (Domains)
```
execute("zones.list", { account_id: "..." })
```

### Get Zone Details
```
execute("zones.get", { zone_id: "..." })
```

### Check DNS Records
```
execute("dns.records.list", { zone_id: "..." })
```

### Check if Cloudflare is serving requests
```
execute("zones.settings.get", { zone_id: "...", setting_id: "development_mode" })
```

Development mode bypasses caching — check if it's accidentally enabled in production.

## Workers Deployments

### List Worker Deployments
```
execute("workers.deployments.list", { account_id: "...", script_id: "script-name" })
```

### Get Worker Routes
```
execute("workers.routes.list", { zone_id: "..." })
```

## Cron Triggers

### List Cron Triggers for a Worker
```
execute("workers.scripts.schedules.get", { account_id: "...", script_name: "..." })
```

### Update Cron Schedule
```
execute("workers.scripts.schedules.update", {
  account_id: "...",
  script_name: "...",
  body: [{ cron: "0 9 * * 1" }]
})
```

## Searching Cloudflare Docs

```
search_cloudflare_documentation("D1 batch operations transactions")
search_cloudflare_documentation("Workers KV consistency model")
```

Returns excerpts from official Cloudflare documentation. Use when the behavior of a platform primitive is unclear.

## Account ID Discovery

If you don't know the account ID:
```
execute("accounts.list", {})
```

Returns all accounts associated with the API token. Use the `id` field from the result.

## Wrangler CLI Reference (Alternative to MCP)

For local development and deployments:
```bash
wrangler whoami                     # verify auth
wrangler deploy                     # deploy worker
wrangler tail                       # live log streaming
wrangler kv:key put KEY VALUE --binding=KV
wrangler d1 execute DB --command "SELECT ..."
wrangler r2 object put bucket/key --file ./file.jpg
wrangler secret put SECRET_NAME     # set encrypted secret
```
