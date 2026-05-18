# Failure: PostgreSQL Deadlocks

## What Happens

A deadlock occurs when two transactions each hold a lock the other needs. Transaction A locks row 1 and waits for row 2. Transaction B locked row 2 and waits for row 1. Neither can proceed. PostgreSQL detects this cycle (usually within 1 second) and kills one transaction with error code `40P01: deadlock detected`.

This isn't a bug in Postgres — it's a consequence of how concurrent transactions interact. The database is doing the right thing; the application needs to handle it.

## How Deadlocks Form

The most common pattern: two code paths update the same two rows but in opposite order.

```
// Worker A: updates user, then order
// Worker B: updates order, then user
```

Under concurrent load, A locks user and B locks order simultaneously — both stall indefinitely until Postgres breaks the cycle.

Other triggers: bulk operations that don't sort their inputs, advisory locks acquired in inconsistent order, foreign key checks locking parent rows.

## Detection

Query `pg_stat_activity` to see waiting transactions:

```sql
SELECT pid, wait_event_type, wait_event, query, state
FROM pg_stat_activity
WHERE wait_event_type = 'Lock';
```

For the lock dependency graph:

```sql
SELECT blocked.pid, blocked.query, blocking.pid AS blocking_pid
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
  ON blocking.pid = ANY(pg_blocking_pids(blocked.pid));
```

Postgres logs deadlocks at `LOG` level when `log_lock_waits = on` and `deadlock_timeout` (default 1s) elapses. Enable this in staging.

## Prevention: Consistent Lock Ordering

The root fix is always acquiring locks in the same order across all code paths. If any operation touches both `users` and `orders`, establish a rule: always lock `users` first.

For bulk operations, sort the rows by primary key before processing:

```ts
const sorted = rows.sort((a, b) => a.id - b.id);
for (const row of sorted) { /* update */ }
```

This eliminates the crossing-lock pattern entirely.

For SELECT ... FOR UPDATE queries, use `NOWAIT` or `SKIP LOCKED` to fail fast rather than queue:

```sql
SELECT * FROM jobs WHERE status = 'pending'
ORDER BY id
FOR UPDATE SKIP LOCKED
LIMIT 10;
```

## Retry Logic

Any code touching Postgres in a transaction must handle `40P01`. The correct response is to retry the entire transaction (not just the failing statement), because the transaction's state is fully rolled back.

```ts
async function withRetry<T>(fn: () => Promise<T>, maxRetries = 3): Promise<T> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err: any) {
      if (err.code === '40P01' && attempt < maxRetries - 1) {
        const backoff = Math.pow(2, attempt) * 50 + Math.random() * 50;
        await new Promise(r => setTimeout(r, backoff));
        continue;
      }
      throw err;
    }
  }
  throw new Error('unreachable');
}
```

Jitter in the backoff prevents two retrying transactions from deadlocking again immediately.

## Key Rules

- **Sort inputs** before any multi-row update. Consistent key order prevents crossing locks.
- **Always retry on `40P01`** — retry the whole transaction, not individual statements.
- **Use `SKIP LOCKED`** for queue-style work tables to avoid lock contention entirely.
- **Enable `log_lock_waits`** in non-production environments to catch deadlock-prone patterns early.
- **Keep transactions short** — the longer a transaction holds locks, the more likely it is to conflict.
