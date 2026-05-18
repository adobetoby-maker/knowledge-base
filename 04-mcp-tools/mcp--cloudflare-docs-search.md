# Cloudflare Documentation Search MCP

## What It Does

`mcp__plugin_cloudflare_cloudflare-docs__search_cloudflare_documentation` searches official Cloudflare documentation. Use it when:
- You need to understand a specific Cloudflare Workers API or binding
- You're implementing a feature that uses Cloudflare-specific capabilities
- Runtime behavior is unclear (CPU limits, memory limits, execution context)
- You need the current syntax for wrangler.toml configuration

## Basic Usage

```
mcp__plugin_cloudflare_cloudflare-docs__search_cloudflare_documentation
{ "query": "workers rate limiting middleware" }
```

## Pages Migration Guide

For projects still on Cloudflare Pages:
```
mcp__plugin_cloudflare_cloudflare-docs__migrate_pages_to_workers_guide
```

This returns step-by-step migration instructions. All new climb-* sites use Workers directly.

## Common Documentation Queries

| Task | Query |
|---|---|
| Worker KV binding syntax | `"KV binding wrangler.toml typescript"` |
| D1 database queries | `"D1 database execute query workers"` |
| R2 object storage | `"R2 storage upload object workers"` |
| Service bindings | `"service bindings workers"` |
| CPU time limits | `"workers CPU time limits"` |
| Cron triggers | `"workers cron trigger wrangler.toml"` |
| Environment secrets | `"workers secret environment variable"` |
| Durable Objects | `"durable objects workers"` |
| Queue consumers | `"queue consumers workers binding"` |

## When Documentation Search Fails

If the docs search returns outdated or missing results, use the Cloudflare API tool to search instead:
```
mcp__plugin_cloudflare_cloudflare-api__search
{ "query": "rate limiting API configuration" }
```

The API search tool covers the Cloudflare REST API reference while the docs tool covers developer guides and tutorials.

## climb-brasil Stack Specifics

`climb-brasil` uses `@opennextjs/cloudflare` — the Next.js adapter for Cloudflare Workers. Its behavior differs from standard Next.js:
- Node.js APIs are unavailable (no `fs`, no `path.join` with OS separators)
- Images need `export const runtime = 'nodejs'` only if using `next/image` optimization
- Environment variables use `wrangler.toml` bindings, NOT `process.env` in the Worker context
- `console.log` output goes to Cloudflare dashboard logs (not terminal)

Search for `@opennextjs/cloudflare` specific documentation:
```
mcp__plugin_cloudflare_cloudflare-docs__search_cloudflare_documentation
{ "query": "opennextjs cloudflare next.js deployment" }
```
