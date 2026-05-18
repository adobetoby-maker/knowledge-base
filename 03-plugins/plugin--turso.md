# Plugin: Turso (Distributed SQLite)

## Purpose
Run SQLite at the edge — distributed, low-latency reads, and globally replicated. Turso wraps libSQL (SQLite fork) and adds replication, branching, and HTTP access. Best fit: read-heavy apps that don't need complex joins, per-tenant databases, or apps that need sub-millisecond latency for simple queries.

## Client Setup
```ts
import { createClient } from '@libsql/client';

export const db = createClient({
  url: process.env.TURSO_DATABASE_URL!,      // libsql://your-db.turso.io
  authToken: process.env.TURSO_AUTH_TOKEN!,
});
```

For edge functions (no Node.js `net` module): use the HTTP client variant:
```ts
export const db = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
  // Turso auto-selects HTTP transport in edge environments
});
```

## Drizzle Integration
Turso pairs well with Drizzle for typed queries:
```ts
import { drizzle } from 'drizzle-orm/libsql';
import { createClient } from '@libsql/client';

const client = createClient({ url: process.env.TURSO_DATABASE_URL!, authToken: process.env.TURSO_AUTH_TOKEN! });
export const db = drizzle(client, { schema });
```

Drizzle migrations work the same as with Postgres — `drizzle-kit generate` + `drizzle-kit migrate`. The SQLite dialect handles DDL differences automatically. Primary difference from Postgres: SQLite types are more flexible (no `serial`, use `INTEGER PRIMARY KEY` for autoincrement; no `uuid` type, store as `TEXT`).

## `batch()` for Atomic Operations
SQLite is synchronous and single-writer. To run multiple mutations atomically, use `batch()` — it sends all statements in a single round trip and wraps them in a transaction:

```ts
await db.batch([
  db.insert(users).values({ id: newId, email }),
  db.insert(profiles).values({ userId: newId, displayName }),
  db.update(accounts).set({ memberCount: sql`member_count + 1` }).where(eq(accounts.id, accountId)),
]);
```

Using individual `await db.insert(...)` calls in sequence is both slower (multiple round trips) and non-atomic (partial writes if one fails). Always use `batch()` for related mutations.

## Embedded Replicas for Zero-Latency Reads
Turso's embedded replica feature syncs a copy of the remote DB into the local filesystem and reads from it without a network call:

```ts
const db = createClient({
  url: 'file:/tmp/local.db',          // local replica path
  syncUrl: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
  syncInterval: 60,                   // sync every 60 seconds
});
await db.sync(); // pull latest changes before serving traffic
```

Reads hit the local file — microseconds. Writes go to the remote DB and are replicated back. This is ideal for: serverless functions with warm instances, Electron apps, edge workers with persistent storage. Cold starts still need one initial `db.sync()`.

## Turso vs Cloudflare D1

| | Turso | Cloudflare D1 |
|---|---|---|
| Latency | Embedded replicas → microseconds | Closest region → ~5-20ms |
| Multi-region | Yes, automated | Yes, via read replication |
| Per-tenant DBs | Excellent — create thousands cheaply | Possible but harder to manage |
| Local dev | `libsql` file, works anywhere | Requires `wrangler dev` or D1 emulation |
| Vendor lock-in | Lower (libSQL is open) | Higher (Cloudflare-specific API) |
| Migrations | Drizzle or `db.batch()` | Wrangler CLI or API |

Use Turso when: not exclusively on Cloudflare, need embedded replicas, or need per-tenant DBs at scale. Use D1 when: already on Cloudflare Workers and want one less vendor.

## Branching
Turso databases can be branched (like git) — useful for staging/preview environments:
```bash
turso db branch create my-db --from main
```
Each branch is an independent DB with its own URL. Use this for PR preview deployments instead of seeding a shared staging DB.

## Key Rules
- **Use `batch()` for related mutations** — individual awaited calls are non-atomic and slower
- **Call `db.sync()` before reads on embedded replicas** — stale reads happen if you skip it on fresh instances
- **Store UUIDs as `TEXT`** — SQLite has no native UUID type; use `crypto.randomUUID()` in application code
- **Prefer Turso over D1 for per-tenant architectures** — creating thousands of databases is cheap and each is isolated
- **Set `syncInterval` on embedded replicas** — don't rely solely on manual `db.sync()` calls
- **Use Drizzle for typed queries** — raw `db.execute(sql)` loses type safety and makes refactors dangerous
