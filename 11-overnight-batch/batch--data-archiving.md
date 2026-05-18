# Data Archiving to Cold Storage

Active database tables grow indefinitely unless you archive old rows. Large tables cause query slowdowns, bloated backups, and longer migration times. Archiving moves aged data to a separate location while keeping it queryable, at a fraction of the storage cost.

## Age Thresholds by Table Type

Set thresholds based on how frequently old data is accessed, not just how old it is:

- **Transactional records** (orders, invoices, payments): archive after 2 years. Tax and audit requirements mean you need these for 7 years, but they rarely need to be accessed after the first year.
- **Application logs / events**: archive after 90 days; delete from archive after 1–3 years per retention policy.
- **Soft-deleted rows**: archive after 30 days; these are already "deleted" from the user's perspective.
- **User-generated content** (posts, uploads) for closed accounts: archive after account closure grace period.

The right threshold is where access frequency drops to near-zero. Check slow query logs and analytics — if old records are being queried frequently, archiving is premature.

## Archive Pattern: INSERT + DELETE

Never UPDATE to mark rows as archived in the same table. The correct pattern is:

```sql
BEGIN;

-- Move rows to archive table
INSERT INTO invoices_archive
SELECT *, NOW() AS archived_at
FROM invoices
WHERE created_at < NOW() - INTERVAL '2 years';

-- Remove from live table
DELETE FROM invoices
WHERE created_at < NOW() - INTERVAL '2 years';

COMMIT;
```

Run in batches of 1,000–10,000 rows per transaction, not millions at once. Bulk deletes hold locks, generate WAL/redo log volume, and can cause replication lag. Sleep briefly between batches.

## Archive Table Schema

The archive table mirrors the source table exactly, plus one column:

```sql
CREATE TABLE invoices_archive AS TABLE invoices WITH NO DATA;
ALTER TABLE invoices_archive ADD COLUMN archived_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
```

Do not add indexes aggressively to archive tables. A single index on `(original_table_pk)` and the date column you query by is sufficient. Archive tables are queried rarely — scans are acceptable.

## Query Routing

Most queries should never touch the archive table. Add the routing logic to a service/repository layer, not to raw SQL:

```ts
async function getInvoice(id: string, includeArchived = false) {
  const live = await db.invoice.findUnique({ where: { id } });
  if (live) return live;
  if (includeArchived) {
    return db.$queryRaw`SELECT * FROM invoices_archive WHERE id = ${id}`;
  }
  return null;
}
```

Expose archive queries only through explicit opt-in (`includeArchived: true` or an admin-only endpoint). Default behavior should never touch archive tables — that's why they exist separately.

For reporting use cases that span all time, use a UNION or a view that combines live + archive. Create the view once; don't repeat the UNION pattern everywhere.

## Cold Storage for True Archives

For data that needs to be retained but almost never queried (compliance, tax records older than 5 years), export archive tables to object storage (S3 Glacier, GCS Nearline) as Parquet or JSONL files. Then drop the archive table from the database entirely.

This cuts database storage costs dramatically. The tradeoff is query latency when you do need the data — Glacier retrieval takes hours. Acceptable for "auditor requested records from 2018" scenarios; unacceptable for anything user-facing.

## Key Rules

- INSERT to archive table + DELETE from live table in a transaction; never archive-in-place with a flag column
- Batch deletes (1k–10k rows); never delete millions of rows in one transaction
- Archive table schema = source schema + `archived_at` column
- Default queries never touch archive tables; require explicit opt-in
- Provide a UNION view for reporting that spans all time
- For 5+ year old compliance data: export to object storage (Parquet/JSONL), drop the DB archive table
- Test restore path: confirm you can actually retrieve and import cold storage exports
