# Principle: Twelve-Factor App

## Relevance

The 12-factor methodology defines what "cloud-native" means for web apps. The factors most relevant to the Next.js + Supabase + Cloudflare stack are: config in env vars, stateless processes, disposability, dev/prod parity. Most violations are in config and state.

## Factor 1: Codebase (One Codebase, Many Deploys)

One git repository per app. Multiple environments (dev, staging, prod) are the same codebase at different commits. Monorepo is OK — each deployable unit still has a single codebase.

Violation: duplicating code between "dev" and "prod" branches. Use environment variables for differences, not separate codebases.

## Factor 3: Config (Store Config in Environment)

```ts
// WRONG — config in code
const DB_URL = 'postgresql://localhost:5432/mydb'
const API_KEY = 'sk-live-abc123'

// CORRECT — config in environment variables
const DB_URL = process.env.DATABASE_URL!
const API_KEY = process.env.RESEND_API_KEY!
```

Rule: can you open-source the codebase today without exposing credentials? If not, there's config in code.

**Environment variable tiers:**
```
NEXT_PUBLIC_*   → Browser-safe (no secrets)
*               → Server-only (secrets OK)
```

## Factor 6: Processes (Stateless)

```ts
// WRONG — state in process memory
let invoiceCache: Invoice[] = []  // Dies on server restart

// CORRECT — state in external store
// Fetch from Supabase (the state store) on every request
const invoices = await supabase.from('invoices').select('*')
```

Next.js Route Handlers and Cloudflare Workers are stateless — they can be restarted, scaled, or moved at any time. State goes in: Supabase (database), Redis/Upstash (cache), Cloudflare KV (config), Cloudflare R2 (files).

Module-level caches (constants, compiled regex) are fine — they're recreated cheaply on restart. Don't cache mutable business data in module scope.

## Factor 7: Port Binding (Self-Contained)

Apps shouldn't depend on an external web server (Apache, nginx). Next.js `npm run start` is the server. Cloudflare Workers ARE the web server.

## Factor 8: Concurrency (Scale Out via Processes)

Scale horizontally (add more instances) not vertically (bigger server). This is the default for Vercel, Cloudflare Workers, and Supabase Edge Functions. Implication: never assume a request is handled by the same process as a previous request.

## Factor 9: Disposability (Fast Startup, Graceful Shutdown)

```ts
// Keep cold start fast
// WRONG — slow initialization at module load
const modelWeights = loadLargeModel()  // 30 second cold start

// CORRECT — lazy initialization
let model: Model | null = null
function getModel() {
  if (!model) model = loadModel()
  return model
}
```

Vercel functions have a 3-second cold start budget. Cloudflare Workers have a 400ms CPU budget per request (Workers must be faster).

## Factor 10: Dev/Prod Parity

Keep development and production as similar as possible:

| Environment | Dev | Prod |
|-------------|-----|------|
| Database | Supabase local (`supabase start`) | Supabase cloud |
| Email | Resend test mode | Resend live mode |
| Payments | Stripe test keys | Stripe live keys |
| Env vars | `.env.local` | Vercel env vars |

The key differences are env vars and external services — not code. If dev uses SQLite and prod uses Postgres, you're running on different databases.

## Factor 11: Logs (Treat as Event Streams)

```ts
// CORRECT — structured logs to stdout
console.log(JSON.stringify({
  level: 'info',
  event: 'invoice_sent',
  invoice_id: invoice.id,
  total_cents: invoice.total_cents,
  ts: new Date().toISOString(),
}))
```

Don't write log files — stdout/stderr goes to Vercel's log aggregator, Cloudflare Workers tail log, or Supabase Edge Function logs. Use structured JSON so logs are searchable.

## The Ones to Internalize

Most of the 12 factors are followed automatically by the stack (Vercel handles processes, disposability, port binding). The ones requiring active attention:

1. **Config** — always env vars, never in code
2. **Stateless processes** — no in-memory state, no local file writes
3. **Dev/prod parity** — local Supabase, same Stripe test keys
4. **Logs** — structured JSON to stdout
