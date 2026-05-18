# Failure: Database Transaction Isolation Level Bugs

## Why Default Isolation Isn't Always Enough

PostgreSQL's default isolation level is **Read Committed**. For most CRUD operations it's fine. But it permits anomalies that corrupt data in concurrent workloads — anomalies that only appear under load, never in local testing, and are nearly impossible to reproduce on demand.

Understanding which anomaly each level prevents is the prerequisite for choosing correctly.

## The Three Anomalies

**Dirty read:** Transaction A reads uncommitted data from Transaction B. Postgres doesn't allow this even at Read Committed — ignore dirty reads for Postgres-specific work.

**Non-repeatable read:** Transaction A reads a row, Transaction B updates and commits it, Transaction A reads again and gets a different value. This happens at Read Committed and is the most common source of "how did this get in this state" bugs.

**Phantom read:** Transaction A runs a query, Transaction B inserts a row that would match the same query, Transaction A runs the query again and gets a different row count. Happens at Read Committed and Repeatable Read.

## Read Committed (Default) — Hidden Risks

```sql
-- Transaction A (balance check + debit)
BEGIN;
SELECT balance FROM accounts WHERE id = 1; -- reads 100
-- Transaction B commits: balance = 50
UPDATE accounts SET balance = balance - 80 WHERE id = 1; -- now -30!
COMMIT;
```

At Read Committed, each statement sees the most recently committed snapshot, not a consistent view. Two statements in the same transaction can see different data. This is the non-repeatable read problem.

Any code that reads a value and then acts on it in a later statement within the same transaction is vulnerable at Read Committed.

## Repeatable Read — Consistent Snapshot

At `REPEATABLE READ`, Postgres takes a snapshot at the start of the transaction. All reads within the transaction see that snapshot. The non-repeatable read anomaly is eliminated.

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM accounts WHERE id = 1; -- 100
-- Transaction B commits: balance = 50
SELECT balance FROM accounts WHERE id = 1; -- still 100 (snapshot)
```

Use Repeatable Read for any operation that: reads a value, does computation, then writes based on that value. Inventory checks, balance deductions, coupon redemptions.

At this level, Postgres detects concurrent write conflicts and throws `ERROR 40001: could not serialize access`. You must retry the transaction.

## Serializable — For Financial Operations

`SERIALIZABLE` is the highest level. Transactions execute as if they were run one after another in some order, with no concurrency anomalies at all. Phantoms are prevented.

```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;
```

Use for: double-entry accounting, anything where the correctness proof requires "only one of these can win." The performance cost is real — Postgres tracks dependencies between transactions, and high-conflict workloads see more serialization failures requiring retries.

Don't use Serializable by default and then complain about performance. Use it specifically where the invariant demands it.

## Performance Cost of Higher Isolation

Each level adds overhead:
- **Read Committed**: minimal overhead, a snapshot per statement
- **Repeatable Read**: snapshot per transaction, write conflict detection
- **Serializable**: full dependency tracking, predicate locking, more aborts

The common mistake is under-isolating (keeping Read Committed) and adding application-level locking (SELECT FOR UPDATE) to compensate. This is often worse than just using Repeatable Read, because advisory locks held across network round-trips create their own contention problems.

Match the isolation level to the operation's actual concurrency requirements. Most reads don't need anything above Read Committed. Writes that depend on reads should use Repeatable Read. Financial ledger operations use Serializable.

## Key Rules

- **Read Committed permits non-repeatable reads** — don't read-then-write in the same transaction at this level without explicit locks.
- **Repeatable Read is correct for inventory/balance checks** — it prevents the phantom balance problem.
- **Serializable is required when "only one can win"** — financial transactions, unique-constraint-adjacent logic.
- **Always retry on `40001` (serialization failure)** with the same logic as deadlock retry.
- **`SELECT FOR UPDATE` at Read Committed is not a substitute for Repeatable Read** — it locks rows but doesn't give a consistent view of non-locked rows.
