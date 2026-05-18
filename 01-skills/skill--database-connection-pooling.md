# Skill: Database Connection Pooling

## Overview
Each database connection consumes memory and file descriptors on the server. Without a connection pool, every request opens and closes a connection — expensive and slow. With too many pool connections, you exhaust the database's `max_connections` limit and requests start queuing. The pool size formula, timeout settings, and serverless considerations are where most misconfiguration happens.

## Implementation

### Pool Size Formula
```
max_connections = (2 × CPU_cores) + 1    for compute-bound queries
max_connections = CPU_cores + disk_count  for I/O-bound queries
```
For a 4-core Postgres server, start with a pool max of ~10 per application instance. This is lower than most developers expect — Postgres handles concurrency via its own internal scheduler, and too many connections cause context-switching overhead.

### Node.js / pg Pool Configuration
```typescript
// lib/db.ts
import { Pool } from "pg";

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,              // max connections in pool per Node.js process
  min: 2,               // keep at least 2 warm connections
  idleTimeoutMillis: 30_000,     // close idle connections after 30s
  connectionTimeoutMillis: 5_000, // fail if can't get connection in 5s
  statement_timeout: 30_000,     // kill queries running > 30s
  application_name: process.env.SERVICE_NAME ?? "app",  // visible in pg_stat_activity
});

// Monitor pool health
pool.on("error", (err) => {
  console.error("Idle pool client error:", err);
});

// Detect connection leaks — client not returned to pool
pool.on("connect", () => console.debug(`Pool size: ${pool.totalCount}`));
```

### Drizzle ORM (with pg Pool)
```typescript
// lib/db.ts
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 5_000,
});

export const db = drizzle(pool, { schema });
```

### Serverless: PgBouncer (Transaction Mode)
In serverless environments (Vercel, Lambda), each function invocation may create a new connection. With 1000 concurrent invocations, you'd open 1000 DB connections — fatal.

Use PgBouncer in **transaction mode** as a connection multiplexer:
```
# pgbouncer.ini
[pgbouncer]
pool_mode = transaction       # connection returned to pool after each transaction
max_client_conn = 1000        # connections from app instances
default_pool_size = 25        # actual DB connections PgBouncer holds

# App connects to PgBouncer, not directly to Postgres
DATABASE_URL=postgres://user:pass@pgbouncer-host:6432/dbname
```

Caveat: transaction mode breaks named prepared statements and `SET` commands — use `?` placeholders, not named statements.

### Connection Leak Detection
```typescript
// Log long-running connections — indicates leak
// Run periodically or as a scheduled query:
SELECT
  pid,
  now() - pg_stat_activity.query_start AS duration,
  query,
  state
FROM pg_stat_activity
WHERE state != 'idle'
  AND query_start < now() - interval '5 minutes'
ORDER BY duration DESC;
```

## Key Rules
- Pool max of 10-20 per app instance is usually correct — the instinct to set it high (100+) causes Postgres to thrash
- Always set `connectionTimeoutMillis` — without it, exhausted pool requests wait forever and cascade into a full service hang
- Set `statement_timeout` on the pool — runaway queries from bugs or attacks can exhaust the pool and block all other queries
- In serverless environments, always use PgBouncer in transaction mode — direct connections from serverless functions exhaust `max_connections` in seconds during load spikes
- Use `application_name` so you can identify which service opened connections via `pg_stat_activity`
- Monitor `pool.totalCount`, `pool.idleCount`, and `pool.waitingCount` — waitingCount > 0 means your pool is undersized for the load
- Never use `SELECT pg_sleep()` or long transactions in connection pool contexts — it holds a connection for the entire duration
