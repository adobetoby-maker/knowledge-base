# Failure: Database Connection Pool Exhaustion

## What It Is

Each database connection is a persistent TCP connection maintained by the server. Connection pools reuse a fixed number of connections. When all connections are in use, new requests wait (timeout) or fail. Symptoms: `timeout acquiring connection`, `too many connections`, or sudden slowness under load.

## Causes

1. **Serverless functions**: each function invocation creates its own connection — 1000 concurrent functions = 1000 connections (Postgres defaults to 100 max).
2. **Missing connection release**: connection acquired but not returned to pool after use.
3. **Long-running transactions**: hold a connection for the duration of a slow query.
4. **Pool size too large**: each connection uses ~5MB on the server; too many connections exhaust server RAM.

## Serverless (Vercel/Edge): Use PgBouncer / Supabase Connection Pooler

```ts
// BAD: Direct connection — creates a new connection per serverless invocation
const db = drizzle(postgres(process.env.DATABASE_URL!))

// GOOD: Use the pooling URL (Supabase provides both)
// Direct: postgresql://user:pass@host:5432/db
// Pooler: postgresql://user:pass@host:6543/db?pgbouncer=true

const db = drizzle(postgres(process.env.DATABASE_POOLER_URL!, { 
  max: 1,  // Serverless: request 1 connection, return immediately
}))
```

Supabase provides a connection pooler (PgBouncer) URL on port 6543. Use this for serverless functions.

## Node.js Long-Running Server

```ts
// Correct pool size for a long-running server
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,                // Max connections (not too many)
  idleTimeoutMillis: 30_000,   // Release idle connections after 30s
  connectionTimeoutMillis: 5_000,  // Fail fast rather than queue forever
})

// Check pool health
pool.on('error', (err) => {
  logger.error('Unexpected error on idle client', err)
})
```

## Detecting Exhaustion

```ts
// Log pool stats
if (pool.totalCount === pool.waitingCount + pool.idleCount) {
  logger.warn({ waiting: pool.waitingCount }, 'Connection pool under pressure')
}
```

Postgres side:

```sql
SELECT count(*), state
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY state;
```

If `active` count is near `max_connections`, you're at risk.

## Fix: Increase max_connections (With Care)

Postgres default is `max_connections = 100`. Each connection uses ~5MB RAM:
- 100 connections = 500MB RAM reserved
- 500 connections = 2.5GB RAM reserved

Instead of raising `max_connections` blindly, use PgBouncer (connection multiplexing) — many application connections share fewer server connections.

## Prisma Specific

Prisma creates one connection per query by default in serverless:

```ts
// Singleton pattern — reuse across invocations in the same Lambda container
import { PrismaClient } from '@prisma/client'

declare global { var prisma: PrismaClient | undefined }
const prisma = global.prisma ?? new PrismaClient()
if (process.env.NODE_ENV !== 'production') global.prisma = prisma

export default prisma
```

Prisma also has `DATABASE_URL` and `DIRECT_URL` for PgBouncer:

```
# .env
DATABASE_URL="postgresql://...?pgbouncer=true"
DIRECT_URL="postgresql://..."  # For migrations (can't run via PgBouncer)
```

## Key Rules

- Serverless functions + direct Postgres = connection exhaustion. Always use a pooler.
- `max: 1` per serverless function with PgBouncer — PgBouncer multiplexes to fewer real connections.
- Use the direct (non-pooled) URL for migrations — `pgbouncer=true` disables prepared statements which migrations need.
- Monitor `pg_stat_activity` during load testing before going to production.
