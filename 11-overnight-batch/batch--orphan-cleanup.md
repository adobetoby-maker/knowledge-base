# Orphan Record Cleanup

Orphaned records accumulate silently. A file in storage with no database reference costs money. An abandoned session with a valid token is a security exposure. A soft-deleted record past its retention window is a compliance liability. Cleanup jobs must be deliberate, auditable, and always dry-run first.

## Identifying Orphaned Storage Objects

A storage object is orphaned when no database row references its key. Find them with a LEFT JOIN anti-pattern:

```sql
-- Example: find storage keys not referenced by any profile
SELECT s.object_key
FROM storage_objects s
LEFT JOIN profiles p ON p.avatar_key = s.object_key
WHERE p.avatar_key IS NULL
AND s.created_at < NOW() - INTERVAL '24 hours';
```

The 24-hour grace period prevents false positives from objects just uploaded but not yet written to the database (race condition window). Adjust the window to your slowest write path.

For multi-bucket setups, run the query per bucket — each bucket likely maps to a different table.

## Abandoned Sessions

Sessions without activity for longer than the session TTL are candidates for deletion. Abandoned means: no last_active update, no associated request logs, and the session created_at exceeds the TTL.

Don't delete sessions that are simply old — a user may have a long-lived token for an API integration. Delete sessions that meet all three: past TTL, no recent activity, no associated API key that would indicate intentional long-lived use.

## Expired Invitations

Invitations have an expires_at timestamp. After expiry, delete them. Before deletion:
- Check if the invitation was accepted — the accepted_at field may be null not because it expired but because it was never sent. An unsent invitation is also an orphan.
- Log the deletion to an audit table (user_id, invitation_id, reason, deleted_at) before removing.

## Soft-Deleted Records Past Retention Window

Soft-delete patterns set a `deleted_at` timestamp instead of removing the row. Retention windows are typically defined by policy (90 days, 1 year). The batch job must:
1. Query for records where `deleted_at < NOW() - INTERVAL '<retention window>'`.
2. Cascade-check dependent records — hard-deleting a parent without handling children causes referential integrity violations.
3. Run dependent cleanup in order: children first, then parent.

Never hard-delete without first verifying no active foreign key references remain, even if the parent is soft-deleted.

## Dry-Run Mode

Every cleanup job must support a `--dry-run` flag that logs what would be deleted without deleting it. Dry-run output should include counts and a sample of records (first 20 IDs). Review the dry-run output before running live.

Pattern:
```typescript
if (dryRun) {
  console.log(`Would delete ${records.length} orphaned objects`);
  console.log("Sample:", records.slice(0, 20).map(r => r.id));
} else {
  await deleteInBatches(records, batchSize: 100);
}
```

Delete in batches of 100–500 rows to avoid long-running transactions that lock tables or spike database load.

## Key Rules

- Always dry-run first; review counts and sample IDs before running live.
- Use a grace period (24h+) when identifying orphaned objects to avoid race condition false positives.
- Cascade deletion order: children before parents; never hard-delete a parent with active child references.
- Log every deletion to an audit table before removing: record ID, reason, timestamp.
- Delete in batches (100–500 rows) to avoid table locks and load spikes.
- Abandoned session cleanup must exclude intentional long-lived API tokens.
