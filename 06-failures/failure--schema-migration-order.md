# Failure: Schema Migration Ordering

## Overview
When multiple developers create database migrations concurrently, or when migrations are applied out of order, the database schema can diverge from what the application code expects. This failure mode is insidious because it does not cause an immediate error — migrations are applied, the build succeeds, but the schema may be wrong, leading to runtime failures that are hard to trace back to a migration ordering problem.

## How Ordering Problems Arise

**Concurrent development:**
```
Developer A (on branch feature/users):
  Creates: 20241105_120000_add_users_table.sql

Developer B (on branch feature/orders):
  Creates: 20241105_120001_add_orders_table.sql
  (orders.sql references users table — assumes it exists)

Merge order: B merges first, then A
Applied order: 20241105_120001 runs before 20241105_120000
Result: orders migration fails because users table doesn't exist yet
```

**Squashing/reordering:**
```
Developer C squashes commits, accidentally renaming:
  20241105_120000_add_users_table.sql → 20241101_add_users_table.sql

Now migration system thinks it's older, runs it out of order
```

**Missing migrations:**
```
Migrations on developer's machine: 001, 002, 003, 004
Migrations on CI: 001, 002, 004 (003 was local-only, never committed)
Result: CI runs 004 without 003 having been applied → CI fails or produces wrong schema
```

## Prevention: Always Rebase Before Creating Migrations

```bash
# Before creating any migration:
git fetch origin
git rebase origin/main  # get all migrations that already exist

# Then create your migration:
npx prisma migrate dev --name "add_orders_table"
# Timestamp is now later than any merged migrations
```

This ensures your migration's timestamp is after all currently merged migrations.

## CI Enforcement

CI must apply migrations in order and fail if any migration was applied out of sequence:

```yaml
# .github/workflows/test.yml
- name: Apply migrations
  run: npx prisma migrate deploy
  # prisma migrate deploy fails if:
  # - a migration is missing from the database that exists in the filesystem
  # - a migration exists in the database that doesn't exist in the filesystem (squash detection)
```

Prisma's `migrate deploy` (not `migrate dev`) is safe for CI — it applies pending migrations in order and detects:
- Migrations in the database not in `prisma/migrations/` → schema drift error
- Migrations in `prisma/migrations/` not in the database → applies them in order

## Prisma Migration Drift Detection

```bash
# Check for schema drift (DB doesn't match migrations)
npx prisma migrate diff \
  --from-migrations ./prisma/migrations \
  --to-schema-datamodel ./prisma/schema.prisma \
  --shadow-database-url $SHADOW_DATABASE_URL
```

If drift is detected, the issue is either:
1. A migration was applied manually to the DB (bad practice — always use Prisma)
2. Migrations were squashed or reordered (undo the squash)
3. The schema was modified directly in the DB console (fix by creating a new migration to bring DB in line)

## Never Modify Committed Migrations

Migrations are append-only. A committed migration is a historical fact — what state the database was in at that point in time. Modifying it creates inconsistency between environments where the old version was already applied.

```
# NEVER DO:
git rebase -i HEAD~3
# (edit: squash migration commit A into migration commit B)
# (force push)
# Result: DB on staging/prod has A applied; new code expects A+B combined; disaster

# CORRECT:
# Create a new migration C that achieves the combined effect of A+B
# A and B remain unchanged historical records
```

## Migration Safety for Rolling Deployments

During rolling deployments, old code and new code run simultaneously with the new schema. Migrations must be backward compatible:

- Adding a nullable column: safe (old code doesn't know about it, ignores it)
- Adding a non-nullable column without default: unsafe (old code won't send a value)
- Dropping a column: unsafe (old code still reads/writes it) — do in two phases
- Renaming a column: unsafe — add new column, backfill, update code, drop old column

## Key Rules
- Always `git rebase origin/main` before `prisma migrate dev` — never create migrations on a stale branch
- Committed migrations are never modified or squashed — they are historical facts
- CI uses `prisma migrate deploy` (not `dev`) — fails on drift
- Local development always uses `prisma migrate dev` — never manual SQL
- Migration files are committed in the same PR as the code that requires them
- Backward-compatible migrations only during rolling deployments (additive, not destructive)
- Shadow database in CI for drift detection and migration verification before applying
