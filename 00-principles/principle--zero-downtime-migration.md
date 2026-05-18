# Principle: Zero-Downtime Migration

## Overview
Schema migrations are the leading cause of production outages during deploys. A column rename that takes 50ms in development can lock a high-traffic table for minutes, dropping all queries during the lock. The expand-contract pattern eliminates this risk by treating migrations as a series of non-breaking, additive steps rather than a single atomic change.

## The Expand-Contract Pattern

Every breaking schema change becomes a three-phase deploy:

**Phase 1 — Expand (additive only)**
Add the new column alongside the old. Both columns exist; the old one is still the source of truth.
```sql
ALTER TABLE users ADD COLUMN email_verified_at TIMESTAMPTZ;
-- Do NOT drop email_verified yet. Do NOT add NOT NULL yet.
```

**Phase 2 — Migrate the application**
Deploy app code that writes to BOTH columns (old and new). Reads from the old column.
Then backfill the new column from the old:
```sql
UPDATE users
SET email_verified_at = created_at
WHERE is_email_verified = true AND email_verified_at IS NULL;
```
Run backfill in batches (1000 rows/iteration) to avoid table locks and replication lag.

**Phase 3 — Contract (remove the old)**
Only after 100% of traffic has moved: make the new column NOT NULL, drop the old column.
```sql
ALTER TABLE users ALTER COLUMN email_verified_at SET NOT NULL;
ALTER TABLE users DROP COLUMN is_email_verified;
```

## Why One-Step Renames Fail

A direct column rename (`ALTER TABLE ... RENAME COLUMN`) causes:
1. Any deployed app code referencing the old name throws immediately
2. The migration takes a brief `ACCESS EXCLUSIVE` lock — fine in dev, catastrophic under load
3. Rollback requires another migration, not a git revert

## Blue-Green vs Rolling Deploys

**Rolling deploys** (Vercel, Railway, Kubernetes rolling update): old and new code run simultaneously for minutes. Any migration must be compatible with BOTH versions at the same time. This is why the expand phase matters — old code ignores the new column, new code writes both.

**Blue-green deploys**: you control the cutover. Still safest to keep migrations backward-compatible for one full release cycle, enabling instant rollback by switching back to the blue environment without a compensating migration.

## Dangerous Anti-Patterns

- `ALTER TABLE ... RENAME COLUMN` in production in a single deploy
- `ALTER TABLE ... ADD COLUMN foo TEXT NOT NULL` without a DEFAULT — locks the table while PostgreSQL rewrites every row
- Running `UPDATE` without a `WHERE` batch limit during business hours
- Coupling migration and app deploy in a single step with no rollback path

## Key Rules
- Never rename a column in one step; always expand-contract over multiple deploys
- `ADD COLUMN ... NOT NULL` requires a `DEFAULT` or pre-backfill, or PostgreSQL will rewrite the entire table
- Backfill in batches of 1000–10000 rows with `WHERE ... LIMIT 1000` loops
- Test migrations on a production-size dataset before running on prod — dev data sizes are misleading
- Keep old columns for at least one full deploy cycle before dropping
- Never couple a breaking migration with the app deploy that depends on it
