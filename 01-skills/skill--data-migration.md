# Skill: Data Migration

## Overview

Move data between schemas, databases, or storage systems without downtime. Categories: schema migrations (add/change columns — covered by ORM migration tools), data backfill migrations (populate new columns from existing data), and cross-system migrations (move from one database to another).

## Schema Migration vs Data Migration

**Schema migration** (use Drizzle/Prisma migrate):
```sql
ALTER TABLE users ADD COLUMN full_name TEXT;
```

**Data migration** (run separately, often after schema):
```sql
UPDATE users SET full_name = first_name || ' ' || last_name WHERE full_name IS NULL;
```

Data migrations are separate from schema migrations — they can take a long time and should not block deployments.

## Safe Backfill Pattern

Never backfill all rows in one query — it locks the table and times out:

```ts
async function backfillUserFullName(): Promise<void> {
  const BATCH_SIZE = 1000
  let lastId: string | null = null
  let totalProcessed = 0

  while (true) {
    const rows = await db.query.users.findMany({
      where: and(
        isNull(users.fullName),
        lastId ? gt(users.id, lastId) : undefined,
      ),
      orderBy: [asc(users.id)],
      limit: BATCH_SIZE,
    })

    if (rows.length === 0) break

    await db.update(users)
      .set({ fullName: sql`first_name || ' ' || last_name` })
      .where(inArray(users.id, rows.map(r => r.id)))

    lastId = rows[rows.length - 1].id
    totalProcessed += rows.length
    console.log(`Backfilled ${totalProcessed} rows...`)

    // Throttle to reduce DB load
    await new Promise(resolve => setTimeout(resolve, 50))
  }

  console.log(`Backfill complete: ${totalProcessed} rows`)
}
```

## Cross-System Migration (ETL)

Migrating from one database to another:

```ts
async function migrateUsers(sourceDb: SourceDB, targetDb: TargetDB) {
  const BATCH_SIZE = 500
  let offset = 0

  // Phase 1: Bulk transfer
  while (true) {
    const rows = await sourceDb.query('SELECT * FROM users ORDER BY id LIMIT $1 OFFSET $2', [BATCH_SIZE, offset])
    if (rows.length === 0) break

    const transformed = rows.map(transformUser)
    await targetDb.batchInsert('users', transformed)

    offset += rows.length
    console.log(`Migrated ${offset} users`)
  }

  // Phase 2: Sync recent changes (CDC / change capture)
  // - Run a second pass for rows updated since the migration started
  // - Or use replication/CDC tool (Debezium, pglogical)
}

function transformUser(source: SourceUser): TargetUser {
  return {
    id: source.id,
    email: source.email.toLowerCase(),  // Normalize
    createdAt: source.created_at,
    // ... map fields
  }
}
```

## Zero-Downtime Deployment Pattern

Expand/contract pattern for adding/removing columns:

```
Phase 1 (Expand): Add new column, write to both old and new
Phase 2 (Migrate): Backfill old column data into new column
Phase 3 (Contract): Read from new column only
Phase 4 (Remove): Drop old column

Example: Renaming email → email_address
1. Add email_address column
2. Write to both email and email_address in application code
3. Backfill: UPDATE users SET email_address = email
4. Switch reads to email_address
5. Drop email column (separate deploy)
```

## Dry-Run Mode

Always build a dry-run mode into migration scripts:

```ts
async function runMigration(opts: { dryRun: boolean }) {
  const rows = await findRowsNeedingMigration()
  console.log(`Found ${rows.length} rows to migrate`)
  
  if (opts.dryRun) {
    console.log('DRY RUN — no changes made')
    console.log('Sample:', rows.slice(0, 5))
    return
  }

  // Actual migration
  await processBatch(rows)
}
```

## Key Rules

- Always test migrations against a production data copy, not just local seed data — edge cases only appear in real data.
- Batches of 500-1000 rows with a short sleep between batches keeps DB load manageable.
- Track migration progress and make resumable (cursor-based, not offset-based — rows can be deleted mid-migration).
- Never run schema migrations and data migrations in the same transaction — data migrations that scan millions of rows should not hold a schema lock.
