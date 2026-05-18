# Plugin: cloudflare@claude-plugins-official

**What it provides:** Cloudflare Workers, Pages, D1, R2, KV — build and deploy skills plus API access.
**When to reach for it:** Building or debugging Cloudflare Workers, configuring edge routing, working with CF storage.

## Key Skills

| Skill | When to Use |
|-------|-------------|
| `cloudflare:cloudflare` | General Cloudflare guidance, which product to use |
| `cloudflare:workers-best-practices` | Workers code patterns, limitations, performance |
| `cloudflare:wrangler` | Wrangler CLI usage — dev, deploy, config |
| `cloudflare:durable-objects` | Stateful Workers — real-time, coordination |
| `cloudflare:agents-sdk` | Cloudflare Agents SDK for AI-powered workers |
| `cloudflare:sandbox-sdk` | Sandboxed code execution in Workers |
| `cloudflare:build-agent` | Build a full Cloudflare Agent |
| `cloudflare:build-mcp` | Build an MCP server on Cloudflare Workers |
| `cloudflare:cloudflare-email-service` | Email routing via Cloudflare |
| `cloudflare:web-perf` | Performance optimization with Cloudflare (Polish, caching, etc.) |
| `cloudflare-workers-expert` | Standalone skill — deep Workers knowledge |

## MCP Tools (cloudflare-api)
The Cloudflare MCP server provides direct API access.
```javascript
ToolSearch("cloudflare-api")  // load available tools
mcp__plugin_cloudflare_cloudflare-api__execute({ ... })
mcp__plugin_cloudflare_cloudflare-api__search({ ... })
```

## Critical Worker Constraints
1. **No Node.js runtime** — Workers run V8 isolates, not Node.js. No `fs`, no `path`, no native Node APIs.
2. **No persistent memory** — each request is stateless. Use KV, D1, or Durable Objects for persistence.
3. **CPU time limits** — 10ms free tier, 30s paid. Long-running code must use `waitUntil()`.
4. **No `setTimeout`/`setInterval`** — use Durable Objects alarms instead.
5. **1MB request size limit** — for large file uploads, stream directly to R2.
6. **KV is eventually consistent** — don't rely on immediate read-after-write.

## Storage Decision Tree
```
Needs SQL queries? → D1 (SQLite at edge)
Key-value, eventually consistent? → KV
Files, images, large blobs? → R2
Real-time coordination, locks? → Durable Objects
Temporary session state? → KV with TTL
```

## Local Dev vs Production
`wrangler dev` simulates the Workers runtime but:
- Some APIs differ slightly (KV, D1 are local mocks)
- Network requests go to the real internet
- Always test on a preview Worker before touching production

## Pattern: Cloudflare Worker as Proxy
The silvercreek-logistics stack uses a Worker for dispatch automation.
Key pattern: Worker receives cron trigger, calls Vercel API, forwards results.
```typescript
export default {
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(runDispatch(env)) // async work after response
  }
}
```
