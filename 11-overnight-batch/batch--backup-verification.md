# Backup Verification

Taking a backup is table stakes. The backup is worthless if it can't be restored. Most teams discover this during an actual incident — the worst possible time to learn that their backup process has been silently failing for three months.

## Why Verification Matters

Backup files can be corrupt, truncated, encrypted with a rotated key, or simply zero bytes. A nightly backup job that exits with code 0 does not mean the backup is valid — it means the backup command completed without a shell error. Verification requires actually restoring and querying the backup.

## Restore to Isolated Environment

Never restore verification to a production or staging database. Spin up a temporary isolated instance:
- Ephemeral database container (Docker or a cloud-managed ephemeral instance).
- Restore the backup file to this instance.
- Run verification queries.
- Tear down the instance after verification.

This ensures verification doesn't pollute production data, doesn't affect production performance, and costs minimally (a 5-minute ephemeral instance is cents).

Automate the full lifecycle: provision → restore → verify → teardown. If teardown fails, alert — a verification environment left running is a cost and security issue.

## Row Count Comparison

After restore, compare row counts between the production snapshot and the restored backup for every critical table:

```sql
-- Run against production at backup time and store results
SELECT 'orders' as tbl, COUNT(*) FROM orders
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'invoices', COUNT(*) FROM invoices;
```

An exact match is the baseline. A row count delta above 0.1% for a static/append-only table is a hard failure. For tables with high write volume between backup and restore, allow a configurable tolerance window (e.g., rows created after the backup timestamp).

## Spot-Check Query Results

Row counts confirm the backup is complete but not that the data is correct. Run 5–10 spot-check queries that test data integrity:
- Fetch a specific known record by primary key and compare field values.
- Check that foreign key relationships hold (no orphaned records post-restore).
- Verify a computed aggregate (total revenue for last month) against a stored expected value.

Store expected spot-check values at backup time; compare at verification time. If the backup process itself is corrupting data, row counts may pass but spot checks will catch it.

## Alert on Failure

Any verification failure must page immediately. Do not log-and-continue — a failed backup verification means the recovery capability is zero until fixed. Alert channels:
- PagerDuty or equivalent for on-call engineer.
- Slack alert to the #ops-alerts channel as a secondary notification.

Include in the alert: which verification step failed, the backup file path/ID, the error details, and the timestamp.

## Weekly Full Restore Test

Once per week (typically Sunday low-traffic window), run a full restore test: restore the entire backup, not just spot-check tables. Verify the application can start and execute a representative set of read queries against the restored database. This catches schema drift, application-level incompatibilities, and migration state mismatches that row-count checks miss.

## Key Rules

- Restore to an isolated ephemeral environment — never verify against production or staging.
- Compare row counts for every critical table; store production counts at backup time.
- Run spot-check queries on known records; compare against values stored at backup time.
- Any verification failure must page immediately — log-and-continue is not acceptable.
- Run a full restore test once per week, not just row count checks.
- Automate teardown of the verification environment; alert if teardown fails.
