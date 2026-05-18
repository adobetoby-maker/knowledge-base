# Failure: Prisma Connection Pool Exhaustion in Serverless

## Overview
Prisma creates a connection pool when instantiated. In serverless functions, each cold start creates a new `PrismaClient` instance with its own pool. Under load, 50 concurrent function invocations × 10 connections per pool = 500 database connections — far exceeding the typical PostgreSQL plan limit of 25–100. The symptom: "too many connections" errors that appear only under moderate load, are hard to reproduce locally, and get worse as traffic scales.

## Why Serverless Is Different

**Traditional server:**
- One process, one `PrismaClient`, one pool of N connections
- 100 requests = 100 queries sharing N connections

**Serverless function:**
- Each invocation may be a new process instance
- Each instance creates its own `PrismaClient` with its own pool
- 100 concurrent invocations = 100 × pool_size connections

Postgres plans:
- Supabase free tier: 60 connections
- Supabase pro tier: ~200 connections
- Neon hobby: 10 connections
- Railway starter: 25 connections

At 50 function invocations with default `connection_limit=10`: you need 500 connections. The database rejects everything above its limit.

## Solution 1: Set connection_limit=1 for Serverless

```
# .env
DATABASE_URL="postgresql://user:pass@host/db?connection_limit=1&pool_timeout=20"
```

With `connection_limit=1`, each function instance holds at most 1 connection. 50 invocations = 50 connections — within most plan limits.

The trade-off: no parallelism within a single invocation. Acceptable for most API handlers which make sequential DB calls anyway.

## Solution 2: Prisma Accelerate (Connection Pooler)

Prisma Accelerate sits between your functions and the database, maintaining a persistent connection pool:

```
Serverless functions (many) → Prisma Accelerate (1 pool) → PostgreSQL (few connections)
```

```bash
npm install @prisma/extension-accelerate
```

```typescript
import { PrismaClient } from '@prisma/client';
import { withAccelerate } from '@prisma/extension-accelerate';

const prisma = new PrismaClient().$extends(withAccelerate());

// .env
DATABASE_URL="prisma://accelerate.prisma-data.net/?api_key=..."
DIRECT_URL="postgresql://..."  // Direct URL for migrations
```

Accelerate also provides query caching, reducing cold start latency.

## Solution 3: PgBouncer (Self-Hosted Pooler)

For Supabase projects, the connection pooler is built in:
```
# Transaction mode pooler (best for serverless)
DATABASE_URL="postgresql://user:pass@db.project.supabase.co:6543/postgres?pgbouncer=true"

# Direct connection (for migrations only)
DIRECT_URL="postgresql://user:pass@db.project.supabase.co:5432/postgres"
```

In `schema.prisma`:
```prisma
datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")
  directUrl = env("DIRECT_URL")  // Used for migrations, bypasses pooler
}
```

`pgbouncer=true` tells Prisma to disable prepared statements (not supported in transaction mode pooling).

## The Global PrismaClient Pattern

Prevent creating multiple instances during development (hot reload) and in edge cases:

```typescript
// lib/prisma.ts
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['query', 'error'] : ['error'],
  });

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}
```

In development, module hot-reload would create a new `PrismaClient` on every file change without this pattern, rapidly exhausting connections.

## Diagnosing Connection Exhaustion

```sql
-- Check current connection count
SELECT count(*) FROM pg_stat_activity;

-- Check connection limit
SHOW max_connections;

-- See connections by application/state
SELECT application_name, state, count(*)
FROM pg_stat_activity
GROUP BY application_name, state
ORDER BY count DESC;
```

If `pg_stat_activity` shows many `idle` connections, PgBouncer or Accelerate is the fix.

## Key Rules
- Never create `new PrismaClient()` inside a request handler — create once at module level
- For serverless: set `connection_limit=1` in DATABASE_URL as a minimum fix
- For Supabase: use the transaction-mode pooler URL (port 6543) with `?pgbouncer=true`
- For migrations: always use the `DIRECT_URL` that bypasses PgBouncer (pooler mode doesn't support DDL transactions)
- Use the global pattern to prevent duplicate instances during hot reload in development
- Monitor `pg_stat_activity` in production — idle connection count that grows with traffic indicates the pool exhaustion pattern
