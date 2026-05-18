# Disambig: Vercel vs Cloudflare Pages

## Overview
Both deploy static sites and server-side code from Git. Vercel is optimized for Next.js (it built it), runs functions on Node.js, and integrates with a managed infrastructure ecosystem. Cloudflare Pages runs functions on the Workers runtime (V8 isolates, not Node.js), sits on Cloudflare's global edge network with no cold starts, and integrates with R2 storage, KV, D1 (SQLite), and other Cloudflare primitives.

## Implementation / Key Points

### Runtime Differences
```typescript
// Vercel Function (Node.js runtime)
import { NextResponse } from 'next/server';
import { readFileSync } from 'fs';  // Node.js APIs available

export async function GET() {
  const data = readFileSync('./data.json', 'utf-8');  // works
  return NextResponse.json(JSON.parse(data));
}

// Cloudflare Worker (V8 isolate — no Node.js)
export default {
  async fetch(request: Request, env: Env) {
    // No fs, no net, no path — use Web APIs only
    const data = await env.KV.get('data');  // Cloudflare KV instead
    return Response.json(JSON.parse(data ?? '{}'));
  },
};
```

Key difference: Cloudflare Workers cannot use Node.js built-ins (`fs`, `net`, `crypto` from Node, `path`). They use Web APIs only (`fetch`, `URL`, `crypto.subtle`, `Response`). Node.js compatibility mode exists but is incomplete.

### Performance Model
```
Vercel Serverless Function:
- Cold start: 50-500ms (Node.js startup)
- Regional (deployed to one region by default, edge config for others)
- Scales to zero automatically

Cloudflare Workers:
- No cold start (V8 isolate startup ~5ms globally)
- Every function runs at the nearest of 300+ edge locations
- Always-on (no cold start penalty)
```
For globally distributed, latency-sensitive workloads, Workers wins. For Node.js-heavy workloads, Vercel is simpler.

### Storage Ecosystem
| Storage Need | Vercel | Cloudflare |
|---|---|---|
| Blob/files | Vercel Blob | R2 (S3-compatible, no egress fees) |
| Key-value cache | Vercel KV (Upstash Redis) | KV (eventually consistent) |
| SQL database | External (Supabase, Neon, Planetscale) | D1 (SQLite at edge) |
| Postgres | External only | Hyperdrive (proxy to external Postgres) |

Cloudflare's integrated storage (R2, KV, D1) has no egress fees between Workers and the storage service. Vercel charges egress for Vercel Blob.

### Next.js on Cloudflare
```typescript
// Works with @cloudflare/next-on-pages
// Restrictions:
// - App Router only (no Pages Router)
// - Edge Runtime only (no Node.js runtime)
// - Some Next.js features unsupported (ISR, some middleware patterns)
```
Cloudflare supports Next.js but it's not a first-class experience. Features that depend on Vercel infrastructure (ISR revalidation, Vercel Analytics, Edge Config) require workarounds.

### Preview Deploys and DX
Both offer Git-based preview deploys. Vercel's DX is more polished: comments on PRs, deployment status checks, team collaboration features, and tight GitHub integration. Cloudflare Pages is functional but more spartan.

### Cost Model
```
Vercel Free: 100GB bandwidth, 100 function hours/month
Vercel Pro ($20/mo): 1TB bandwidth, 1000 function hours/month

Cloudflare Pages Free: Unlimited requests, 100,000 Worker invocations/day
Cloudflare Workers Paid ($5/mo): 10 million requests/month included
```
For high-volume sites, Cloudflare's pricing scales better. Vercel's bandwidth costs can become significant.

## Key Rules
- Use Vercel for Next.js projects — it's the native platform, all features work without workarounds
- Use Cloudflare Pages/Workers when: no cold starts required, global edge needed, cost at scale matters, using Cloudflare bindings (R2, KV, D1)
- Node.js built-ins (fs, net, path) don't work in Cloudflare Workers — any library using them will fail
- Cloudflare Workers have a 1MB CPU time limit (not wall clock) — CPU-intensive work won't fit
- Don't deploy Next.js to Cloudflare unless you've verified all features used are compatible
- R2 + Workers is a compelling combination for media-heavy apps due to zero egress fees
