# Batch Job: Data Cleanup

## Overview

Remove or archive stale data to keep the database lean and performant. Unchecked data growth causes slow queries, increasing storage costs, and harder debugging. Run cleanup jobs during off-peak hours. Make every cleanup job safe to run multiple times (idempotent) and log what was removed.

## What to Clean

| Data | Retention | Cleanup |
|---|---|---|
| Soft-deleted records | 30 days | Hard delete |
| Expired sessions | After expiry | Hard delete |
| Anonymous activity logs | 90 days | Hard delete |
| Temp files (uploads in progress) | 24 hours | Delete from storage |
| Expired coupons | 1 year | Archive or delete |
| Old audit logs | 2 years | Archive to cold storage |
| Stale push subscriptions | After 410 response | Already handled |
| Orphaned records | — | Check and remove |

## Safe Cleanup Pattern

```ts
async function cleanupExpiredSessions(): Promise<{ deleted: number }> {
  const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)  // 7 days

  const result = await db
    .delete(sessions)
    .where(lt(sessions.expiresAt, cutoff))
    .returning({ id: sessions.id })

  logger.info({ deleted: result.length, cutoff }, 'Expired sessions cleaned')
  return { deleted: result.length }
}
```

## Soft Delete Cleanup

```ts
async function cleanupSoftDeleted(table: string, retentionDays: number): Promise<void> {
  const cutoff = subDays(new Date(), retentionDays)

  // DRY RUN first
  const count = await db.execute(sql`
    SELECT COUNT(*) FROM ${sql.identifier(table)}
    WHERE deleted_at IS NOT NULL AND deleted_at < ${cutoff}
  `)
  logger.info({ table, count: count[0].count, cutoff }, 'Soft delete cleanup preview')

  // Actual deletion in batches (avoid long locks)
  while (true) {
    const deleted = await db.execute(sql`
      DELETE FROM ${sql.identifier(table)}
      WHERE id IN (
        SELECT id FROM ${sql.identifier(table)}
        WHERE deleted_at IS NOT NULL AND deleted_at < ${cutoff}
        LIMIT 1000
      )
    `)
    if (!deleted.rowCount) break
    await new Promise(r => setTimeout(r, 100))  // Brief pause between batches
  }
}
```

## Orphan Detection and Cleanup

Find records with broken foreign key references:

```ts
async function cleanupOrphanedFiles(): Promise<void> {
  // Find storage files not referenced in the DB
  const allKeys = await listStorageFiles('uploads/')
  const referencedKeys = await db.execute(sql`
    SELECT file_key FROM user_files UNION
    SELECT avatar_key FROM users WHERE avatar_key IS NOT NULL UNION
    SELECT logo_key FROM organizations WHERE logo_key IS NOT NULL
  `)

  const referenced = new Set(referencedKeys.map((r: { file_key?: string; avatar_key?: string; logo_key?: string }) => 
    r.file_key ?? r.avatar_key ?? r.logo_key
  ))

  const orphans = allKeys.filter(k => !referenced.has(k))
  logger.info({ orphanCount: orphans.length }, 'Found orphaned files')

  // Delete in batches
  for (const key of orphans) {
    await deleteStorageFile(key)
  }
}
```

## Archival to Cold Storage

For data you need to keep but rarely access:

```ts
async function archiveOldAuditLogs(): Promise<void> {
  const cutoff = subYears(new Date(), 2)

  // Export to S3/R2 as compressed JSONL
  const cursor = db.query.auditLogs.findMany({
    where: lt(auditLogs.createdAt, cutoff),
    orderBy: [asc(auditLogs.createdAt)],
    limit: 10000,
  })

  const buffer: string[] = []
  for await (const batch of cursor) {
    for (const log of batch) {
      buffer.push(JSON.stringify(log))
    }
    if (buffer.length >= 10000) {
      const filename = `audit-archive-${Date.now()}.jsonl`
      await uploadToStorage(`archives/${filename}`, buffer.join('\n'), 'text/plain')
      buffer.length = 0
    }
  }

  // Now delete archived records
  await db.delete(auditLogs).where(lt(auditLogs.createdAt, cutoff))
}
```

## Cleanup Job Orchestration

```ts
async function runDailyCleanup(): Promise<void> {
  const jobs = [
    { name: 'expired-sessions', fn: cleanupExpiredSessions },
    { name: 'soft-deleted-30d', fn: () => cleanupSoftDeleted('posts', 30) },
    { name: 'orphaned-files', fn: cleanupOrphanedFiles },
  ]

  for (const job of jobs) {
    const start = Date.now()
    try {
      const result = await job.fn()
      logger.info({ job: job.name, durationMs: Date.now() - start, ...result }, 'Cleanup complete')
    } catch (err) {
      logger.error({ job: job.name, err }, 'Cleanup job failed')
    }
  }
}
```

## Key Rules

- Always delete in batches of ≤1000 rows. Large single `DELETE` statements lock the table for seconds.
- Log before and after counts for every cleanup operation — know exactly what was removed.
- Never skip the confirmation check for irreversible deletes — compare count before delete vs after.
- Foreign keys with `ON DELETE CASCADE` clean up child records automatically — verify this is what you want before adding the constraint.
- Schedule cleanup during the lowest traffic period (usually 2-5 AM in the primary timezone).
