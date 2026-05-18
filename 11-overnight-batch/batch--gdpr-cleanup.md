# GDPR Data Retention Cleanup

GDPR requires that personal data not be retained longer than necessary for its original purpose. Most applications collect data that should expire but never delete it because deletion is harder than collection. This batch implements the deletion schedule.

## Why Automated Cleanup Matters

Without automated retention enforcement, your data is accumulating indefinitely. If you're breached after a user deleted their account three years ago, you're exposed for data you had no right to keep. The ICO and other regulators specifically look for data retained beyond stated purposes.

The cleanup batch is the enforcement mechanism for your privacy policy's retention statements. If your policy says "we keep logs for 90 days," a batch that deletes 91-day-old logs is what makes that true.

## Deletion Schedule by Data Category

These are reasonable defaults — adjust to match your actual privacy policy:

**Account data** (profile, preferences, settings): delete or anonymize 30 days after account closure. The 30-day window is a grace period for users who reactivate. On day 31, the account should be purged or fully anonymized.

**Application logs** (request logs, error logs, audit logs): 90 days. Operational logs have no business purpose after 90 days. Exception: security audit logs (authentication events, access control changes) — retain 12 months for incident response, then delete.

**Analytics events** (product usage events, click streams): 12–24 months depending on your analytics use case. Aggregate the data before deletion if you need historical trends without individual records.

**Backups**: 1 year. Backups must be covered by the same retention policy. Deleting a record in production means nothing if it lives in a backup you restore from. Document that backups older than 1 year are destroyed.

**Content created by users** (posts, files, uploads): retain as long as the account is active. On account closure, follow account data rules above.

## Anonymization vs Deletion

Anonymization is sometimes preferable to deletion:

**Anonymize when**: you need the record for aggregate analysis or audit trail but don't need the identity. Replace PII fields with null or with a fake: `email = null`, `name = 'Deleted User'`, `ip_address = '0.0.0.0'`.

**Delete when**: the entire record exists only to serve the user — no operational, financial, or legal hold. User profile rows, session tokens, notification preferences.

Key principle: if the record retains any connection to a specific individual after anonymization (via indirect identifiers like rare combinations of fields), it's not truly anonymized — delete it instead.

Financial records (invoices, transactions) cannot be deleted due to tax law and accounting requirements. Anonymize the billing name/address but retain the transaction record. Clearly document this exception in your privacy policy.

## Compliance Audit Log

Every deletion and anonymization performed by this batch must be logged in an append-only audit table:

```sql
-- gdpr_deletion_log
id, batch_run_id, table_name, record_count, action (delete|anonymize),
data_category, retention_policy_days, executed_at
```

Do not log individual deleted record IDs (that defeats the purpose of deletion). Log counts per table per run. This log itself should have a long retention (7 years) and is what you present to regulators showing that your deletion process runs as stated.

## Batch Safety

Always run in dry-run mode first (log what would be deleted, delete nothing). Compare dry-run counts to expectations before running live. Add a circuit breaker: if the batch would delete more than X% of a table in one run, abort and alert — this indicates either a bug or a policy misconfiguration.

## Key Rules

- Account data: delete/anonymize 30 days after closure; logs: 90 days; backups: 1 year
- Anonymize financial records rather than delete (tax law); document this exception in privacy policy
- Keep an append-only audit log of deletion runs — log record counts, not individual IDs
- Always dry-run first; circuit-break on unexpectedly large deletion counts
- Backup retention must match or be shorter than primary data retention policy
- Aggregate analytics data before deleting individual events if trends are needed
- This batch is the enforcement of your privacy policy — run it on schedule
