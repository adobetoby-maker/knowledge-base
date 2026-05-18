# Race Condition in Concurrent Requests

Race conditions in web applications are not rare edge cases — they are the default in any system that serves multiple users. Any operation that reads, modifies, and writes shared state is a potential race, and the window only needs to be open for a fraction of a millisecond.

## The Lost-Update Problem

The classic race condition is the lost update:

1. Request A reads `balance = 100`
2. Request B reads `balance = 100`
3. Request A writes `balance = 100 - 30 = 70`
4. Request B writes `balance = 100 - 50 = 50`

The correct final balance is `100 - 30 - 50 = 20`. The actual result is `50`. Request A's update was silently lost.

This happens any time two transactions follow the read-modify-write pattern on the same row without coordination. It doesn't require high traffic — two requests arriving within the same millisecond is enough.

## Optimistic Locking

Optimistic locking assumes conflicts are rare. Reads are unrestricted; conflict detection happens at write time.

Add a `version` column (integer, incremented on every write) or `updated_at` timestamp. The write includes a `WHERE` clause that checks the version hasn't changed:

```sql
UPDATE accounts
SET balance = $new_balance, version = version + 1
WHERE id = $id AND version = $expected_version;
```

If another transaction modified the row between the read and the write, `version` no longer matches and the UPDATE affects 0 rows. The application detects this (rows affected = 0), treats it as a conflict, and retries or returns an error to the user.

This is the right pattern for user-facing operations where conflicts are genuinely rare (most user profile updates, most settings changes). The user may occasionally see "someone else modified this — please try again," but lock contention is zero.

## Pessimistic Locking

Pessimistic locking assumes conflicts are likely. The row is locked at read time, blocking other transactions until the lock is released.

```sql
BEGIN;
SELECT * FROM accounts WHERE id = $id FOR UPDATE;
-- other transaction trying to SELECT FOR UPDATE on same row blocks here
UPDATE accounts SET balance = $new_balance WHERE id = $id;
COMMIT;
```

`SELECT FOR UPDATE` acquires a row-level write lock. Any other transaction attempting `SELECT FOR UPDATE` on the same row will block until the first transaction commits or rolls back.

Use pessimistic locking when:
- Conflicts are frequent (high-contention counters, seat reservations, inventory decrement)
- The cost of retry/conflict resolution is high (e.g., user experience degradation)
- The read-to-write path is complex enough that retrying is non-trivial

Warning: long-held locks can create deadlocks and reduce throughput significantly. Keep the transaction short.

## Database-Level UPSERT

For insert-or-update patterns (e.g., "create if not exists, otherwise update"), use `INSERT ... ON CONFLICT` rather than SELECT-then-INSERT:

```sql
INSERT INTO user_preferences (user_id, theme, updated_at)
VALUES ($user_id, $theme, NOW())
ON CONFLICT (user_id)
DO UPDATE SET theme = EXCLUDED.theme, updated_at = NOW();
```

This is atomic at the database level. The application-level pattern of `SELECT → if not exists → INSERT` has a race between the check and the insert, and is always wrong for correctness under concurrency.

## Atomic Increments

For counters, never read-increment-write. Use atomic SQL:

```sql
UPDATE posts SET view_count = view_count + 1 WHERE id = $id;
```

This is a single atomic operation. No read is needed, so there's no window for a race.

## Key Rules

- Any read-modify-write sequence on shared state is a potential lost-update race condition
- Optimistic locking (`WHERE version = $expected`) is the right default for low-contention operations; handle 0-rows-affected as a conflict
- Pessimistic locking (`SELECT FOR UPDATE`) is correct for high-contention operations; keep transactions short to avoid deadlocks
- Use `INSERT ... ON CONFLICT DO UPDATE` (UPSERT) instead of application-level SELECT-then-INSERT
- Use atomic SQL increments (`SET count = count + 1`) instead of read-increment-write
- No application-level locking (mutexes, in-memory flags) substitutes for database-level coordination in multi-process or serverless environments
