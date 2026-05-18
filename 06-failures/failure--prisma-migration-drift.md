# Failure: Prisma Migration Drift (Shadow DB Out of Sync)

## What Drift Is and Why It Happens

Prisma's migration system works by tracking applied migrations in the `_prisma_migrations` table and using a shadow database to safely compute diffs. Drift occurs when the actual database schema no longer matches what Prisma expects based on the migration history. The most common cause: someone ran raw SQL directly against the database (adding a column, creating an index, modifying a constraint) without creating a corresponding migration file.

Prisma detects drift when you run `prisma migrate dev` and the shadow database diff doesn't match the expected state. The error message is typically: `The current database schema is not in sync with the migration history`.

This is dangerous because Prisma may generate a migration that appears to only add something new, when in reality it's also trying to drop or recreate something that was added out-of-band. Running that migration destroys data.

## Detecting Drift Before It Causes Problems

```bash
# Compare current DB schema against migration history baseline
npx prisma migrate diff \
  --from-migrations ./prisma/migrations \
  --to-schema-datamodel prisma/schema.prisma \
  --shadow-database-url "$SHADOW_DATABASE_URL"
```

Run this in CI before deploying to catch drift early. If output is empty, schemas are in sync. Any output describes the gap.

```bash
# Check if the DB has unapplied schema changes not in migration files
npx prisma migrate status
```

`migrate status` will list which migrations are applied, pending, or failed, and warns if the database schema has diverged.

## Resolving Drift Without Data Loss

**When a migration was run manually on production and you need Prisma to acknowledge it:**

```bash
# Mark a migration as applied without actually running it
npx prisma migrate resolve --applied "20240101_add_user_preferences"
```

This tells Prisma "this migration is already applied" — it adds a record to `_prisma_migrations` without executing SQL. Use this when you've already applied the SQL manually and need Prisma's state to match reality.

**When production has schema changes not in any migration file:**

1. Export the current production schema: `pg_dump --schema-only`
2. Create a new baseline migration that reflects reality
3. Mark it as applied with `--applied`

Never use `prisma migrate reset` on production — it drops and recreates the database.

## Why Raw SQL Directly Is Dangerous

When you run `ALTER TABLE` directly on a production database:
- The `_prisma_migrations` table doesn't know about it
- The shadow database used for diff computation doesn't have it
- Next `prisma migrate dev` computes a diff that includes reversing your manual change
- Applying that generated migration can drop the column you just added

The safe way to make schema changes outside of migrations: either always go through `prisma migrate dev` to generate a migration, or use `prisma migrate resolve --applied` to register manual changes after the fact.

## Baseline for Existing Databases

When adding Prisma to a database that already has a schema:

```bash
# Create an initial migration that matches current state, mark it as already applied
npx prisma migrate diff \
  --from-empty \
  --to-schema-datamodel prisma/schema.prisma \
  --script > prisma/migrations/0_init/migration.sql

npx prisma migrate resolve --applied 0_init
```

This creates the initial migration file but does not run it — Prisma treats the existing schema as the baseline.

## Key Rules

- Never run raw DDL (`ALTER TABLE`, `CREATE INDEX`, `DROP COLUMN`) directly on a Prisma-managed database
- Run `prisma migrate status` in CI before every production deploy
- Use `prisma migrate resolve --applied` to reconcile manual changes that are already applied
- Use `prisma migrate diff` to inspect what Prisma thinks needs to change before applying anything
- Never use `prisma migrate reset` on any database with real data
- When adding Prisma to an existing DB, create a baseline migration and mark it applied before writing any schema changes
