# Data Deduplication Batch Job

Duplicate records accumulate from form resubmissions, import errors, API retries without idempotency, and merges of separate data sources. Deduplication is high-stakes: merging the wrong records destroys data; failing to merge leaves the database unreliable. Proceed carefully with auditable, reversible steps.

## Fuzzy Matching for Detection

Exact-match deduplication (same email address) is easy but catches only a fraction of duplicates. Fuzzy matching catches:
- **Email normalization**: `user+tag@gmail.com` and `USER@GMAIL.COM` are the same address. Normalize to lowercase, strip `+tag` suffixes for Gmail/Google Workspace, before comparing.
- **Name similarity**: "Robert Smith" and "Bob Smith" are likely the same person. Use trigram similarity (Postgres `pg_trgm` extension: `similarity(name_a, name_b) > 0.8`) rather than substring matching.
- **Phone normalization**: `(208) 595-2101` and `+12085952101` are the same number. Strip non-digits, apply country code normalization before comparing.
- **Address similarity**: fuzzy match on normalized address strings; dedupe by zip + fuzzy street match.

Combine signals: a record pair with the same email is almost certainly a duplicate; a pair with same name and same city is a candidate requiring more signals.

## Canonical Record Selection

When two records are identified as duplicates, pick one as canonical before merging. Selection criteria in priority order:
1. The record with more non-null fields (more complete data wins).
2. The record that was created earlier (original is canonical over re-registration).
3. The record with more related records (has orders, has sessions — more established).

Never pick canonical based on arbitrary ID ordering — it's not reproducible when records are added.

## Merge Strategy

Merge all surviving data into the canonical record before soft-deleting the duplicate:

- **Prefer non-null fields**: for each field, use the canonical value if non-null; otherwise fall back to the duplicate's value.
- **Prefer newest for timestamped fields**: `last_login_at` should be the most recent of both records.
- **Preserve all related records**: update foreign keys on all child records to point to the canonical ID before soft-deleting the duplicate.
- **Concatenate opt-in lists**: if both records have separate tag arrays or preferences, union them.

Never hard-delete the duplicate record immediately — soft-delete with `merged_into_id` pointing to the canonical. This allows reversal.

## Audit Log of Merges

Write every merge to an audit table before executing:

```sql
INSERT INTO dedup_audit (
  duplicate_id, canonical_id, match_signals, match_score,
  merged_at, merged_by, fields_merged
) VALUES (...);
```

The `match_signals` column stores what caused the match (email, name+phone, etc.) and the confidence score. This lets you:
- Review borderline merges after the fact.
- Reverse a bad merge by looking up `merged_into_id` on the soft-deleted record.
- Monitor merge quality over time (if match scores are drifting, the fuzzy threshold needs tuning).

## Key Rules

- Normalize before comparing: lowercase email, strip phone punctuation, trim whitespace from names.
- Canonical selection must be deterministic and documented — never arbitrary ID ordering.
- Update all child foreign keys before soft-deleting the duplicate.
- Soft-delete with `merged_into_id` reference; never hard-delete immediately.
- Write to the audit table before executing the merge, not after.
- Review a sample of borderline-score merges manually before running at scale; false positives in deduplication destroy data.
