# plugin--pg (node-postgres)

node-postgres (`pg`) is the direct PostgreSQL driver for Node.js — no ORM, no query builder, just parameterized SQL over a connection pool.

## Pool vs Client — Always Use Pool

`Client` opens a single connection and blocks until released. `Pool` maintains a set of reusable connections and queues queries automatically. In any server process, use `Pool`.

```ts
import { Pool } from 'pg';
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
// One pool per process — reuse globally, never create per-request
```

Creating a pool per request is a severe memory/connection leak. Instantiate once at module load and export. On Lambda/serverless, use `pg-pool` with `max: 1` or `maxUses: 1000` and set `idleTimeoutMillis` short to avoid connection exhaustion across cold starts.

## Parameterized Queries — $1 Syntax

Never interpolate values into query strings. `$1`, `$2`, ... are positional placeholders; the values array is the second argument to `query()`.

```ts
const { rows } = await pool.query(
  'SELECT * FROM users WHERE email = $1 AND status = $2',
  [email, 'active']
);
```

This is not a stylistic choice — it's the only safe path against SQL injection. pg handles type coercion: pass a JS number for an integer column, a `Date` for a timestamp, etc. Do not pre-format values into strings.

## Transaction Pattern

Transactions require a dedicated `Client` checked out from the pool. Pool-level `query()` cannot span transactions because each call may land on a different connection.

```ts
const client = await pool.connect();
try {
  await client.query('BEGIN');
  await client.query('INSERT INTO orders ...', [...]);
  await client.query('UPDATE inventory ...', [...]);
  await client.query('COMMIT');
} catch (err) {
  await client.query('ROLLBACK');
  throw err;
} finally {
  client.release(); // ALWAYS release — even on success and error
}
```

Forgetting `client.release()` in the `finally` block leaks the connection permanently (until pool timeout). This is the single most common pg bug.

## JSON Column Handling

pg automatically parses `json` and `jsonb` columns into JS objects on read. On write, pass a plain JS object — pg serializes it with `JSON.stringify`:

```ts
await pool.query('UPDATE configs SET data = $1 WHERE id = $2', [
  { theme: 'dark', locale: 'en' }, // passed as-is, pg serializes
  configId
]);
const { rows } = await pool.query('SELECT data FROM configs WHERE id = $1', [id]);
rows[0].data; // already a JS object, not a string
```

If pg returns JSON as a string (can happen with older driver versions), configure a custom type parser:
```ts
import { types } from 'pg';
types.setTypeParser(114, JSON.parse);  // json
types.setTypeParser(3802, JSON.parse); // jsonb
```

## LISTEN/NOTIFY for Real-Time Events

`NOTIFY` from any Postgres session, `LISTEN` on a dedicated `Client` (not pool) — pool connections get returned between queries, which drops the listener.

```ts
const listener = new Client({ connectionString: process.env.DATABASE_URL });
await listener.connect();
await listener.query('LISTEN channel_name');
listener.on('notification', (msg) => {
  const payload = JSON.parse(msg.payload ?? '{}');
  // handle event
});
// Keep this client open for the process lifetime
// On SIGTERM: await listener.end()
```

`pg_notify('channel_name', payload::text)` from a trigger or application code triggers the event. Payload is limited to ~8000 bytes — send an ID and fetch the full record, never the full row.

## Key Rules

- **One Pool per process** — never per-request, never per-query
- **Always `$1` placeholders** — never string interpolation
- **Transactions need a dedicated Client** — acquire with `pool.connect()`, always `release()` in `finally`
- **LISTEN requires a persistent Client** — pool connections get recycled and drop listeners
- **JSON columns auto-parse** — don't double-serialize with `JSON.stringify` before insert
- **Serverless**: set low `max` and `idleTimeoutMillis` to avoid connection exhaustion
