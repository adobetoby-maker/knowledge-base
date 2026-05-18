# Principle: Twelve-Factor App

## Overview

The Twelve-Factor methodology describes how to build software-as-a-service apps that are portable, scalable, and maintainable. Not all 12 factors apply to every project, but most of them map directly to common failure modes in deployed web apps.

## The Factors That Matter Most for Next.js / Cloudflare

### Factor III: Config — Store config in the environment

Config is anything that varies between deploys (dev/staging/production). It does not belong in the codebase.

```ts
// WRONG — hardcoded config
const STRIPE_KEY = 'sk_live_abc123'

// WRONG — config in a committed file
import config from './config.json'

// CORRECT — environment variable
const STRIPE_KEY = process.env.STRIPE_SECRET_KEY
if (!STRIPE_KEY) throw new Error('STRIPE_SECRET_KEY is not set')
```

Validate required env vars at startup, not at first use. A missing var that crashes the server on boot is far better than a missing var that corrupts a live transaction an hour in.

### Factor IV: Backing Services — Treat them as attached resources

Your database, cache, email service, and S3 bucket are attached resources. They're configured via URL, not hardcoded. You should be able to swap them by changing an env var.

```ts
// CORRECT — database as an attached resource
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
)
```

### Factor VI: Processes — Execute the app as stateless processes

Stateless means: nothing written to disk or memory during request handling that a future request depends on. In-memory sessions, local file uploads, and cached data that isn't in a shared store all violate this.

Implications:
- Sessions must be in cookies or a shared store (Redis, Supabase), not server memory
- File uploads must go directly to S3/R2/Supabase Storage, not the local filesystem
- Caches must be in Redis/Upstash, not `global.cache = {}`

Serverless (Vercel, Cloudflare Workers) enforces this for you — there's no persistent process.

### Factor VII: Port Binding — Export services via port binding

Not directly relevant for serverless apps, but the principle translates: your application should be self-contained. Don't rely on a web server that's external to your codebase (like Apache or Nginx) to handle routing. Next.js is self-contained.

### Factor VIII: Concurrency — Scale out via the process model

Scale horizontally by adding more instances, not vertically by adding more RAM. Serverless enforces this. Design for N concurrent instances — no process-level state, no in-process coordination.

### Factor IX: Disposability — Maximize robustness with fast startup and graceful shutdown

Start fast. Clean up on shutdown. For serverless functions this mostly means:
- Don't defer initialization work to the first request — do it at module load time
- Close database connections in shutdown hooks
- Make operations idempotent so restarts don't cause double-processing

### Factor X: Dev/Prod Parity — Keep development, staging, and production as similar as possible

The most common gap: local dev uses SQLite, production uses PostgreSQL. Schema-level behaviors differ (case sensitivity, JSON handling, transaction isolation). Use the same database engine in all environments.

```bash
# Use local Supabase, not a SQLite substitute
npx supabase start  # runs Postgres locally in Docker
```

### Factor XI: Logs — Treat logs as event streams

Don't write log files. Write to stdout/stderr. Let the platform collect them.

```ts
// WRONG — log to file
fs.appendFileSync('app.log', `Error: ${err.message}`)

// CORRECT — stdout
console.error('Upload failed', { userId, error: err.message })
```

Structured JSON logs (not plain strings) work best with log aggregation tools:

```ts
console.log(JSON.stringify({
  level: 'error',
  message: 'Upload failed',
  userId,
  errorCode: err.code,
  timestamp: new Date().toISOString(),
}))
```

### Factor XII: Admin Processes — Run admin/management tasks as one-off processes

Database migrations, backups, seed scripts — these are one-off processes, not scheduled jobs embedded in your web server. Run them as scripts:

```bash
# Correct — a one-off script
npx ts-node scripts/migrate.ts
npm run seed

# Wrong — a /api/run-migration endpoint that anyone could call
```

Protect one-off scripts with environment checks (never run seed in production) and authentication if exposed via HTTP.
