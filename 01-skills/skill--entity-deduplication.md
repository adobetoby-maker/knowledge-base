# Entity Deduplication

## Why Deduplication Is Hard

Duplicates enter through multiple channels: manual entry by different users, CSV imports from different systems, API webhooks that fire twice, and case/whitespace variations humans don't notice. The danger isn't identifying duplicates — it's merging them. A bad merge destroys data permanently. Always preserve the audit trail and make merges reversible.

## Step 1: Normalize Before Comparing

Raw strings are useless for comparison. Normalize first:

```ts
function normalize(value: string): string {
  return value
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ')           // collapse internal whitespace
    .replace(/[^\w\s]/g, '')        // strip punctuation
    .replace(/\b(inc|llc|ltd|co|corp|the)\b/g, '') // strip company suffixes
    .trim();
}
```

For names: normalize both `"first last"` and `"last, first"` to the same canonical order before comparing. For emails: lowercase only (the local part is case-sensitive per spec, but no real system treats it as such). For phone numbers: strip everything except digits, normalize to E.164.

Store the normalized version in a separate column (`name_normalized`) — don't overwrite the user-supplied value. The original is truth; the normalized form is for matching only.

## Step 2: Candidate Generation

Comparing every record to every other record is O(n²) — unusable at scale. Use blocking to narrow candidates:

- **Exact block**: same first 3 chars of normalized name + same ZIP code → only compare within that block.
- **Soundex / metaphone**: group phonetically similar names.
- **Token sort**: split name into words, sort alphabetically, compare the sorted string — catches "John Smith" vs "Smith, John".
- **Email domain**: two contacts at the same company domain are candidate duplicates worth human review.

A blocking strategy trades recall for performance. Run multiple blocking strategies and union the candidate sets.

## Step 3: Fuzzy Matching

For each candidate pair, compute similarity:

**Levenshtein distance**: number of single-character edits. Good for typos. Use normalized ratio: `1 - (distance / max(len_a, len_b))`. Threshold ≥ 0.85 for high confidence.

**Jaro-Winkler**: weighted toward prefix agreement — better for proper names where the start is usually correct.

**Token set ratio**: split into word tokens, compare sets — handles word-order differences and extra words well.

Don't rely on a single algorithm. Combine scores with weights appropriate to the entity type. A composite score > 0.9 → auto-merge candidate. 0.7–0.9 → human review queue. < 0.7 → not a duplicate.

## Step 4: Canonical Record Selection

When merging, one record becomes canonical (survives). Selection criteria in priority order:

1. Most data completeness (fewest null fields).
2. Oldest created date (original is usually more reliable).
3. Most recent activity (most used = most current).
4. Manual override flag.

The loser record is not deleted — it is soft-deleted and linked to the winner:

```sql
alter table contacts add column merged_into uuid references contacts(id);
alter table contacts add column merged_at timestamptz;
```

All foreign keys pointing to the loser must be repointed to the winner. Use a migration script, not application code, for bulk repointing.

## Step 5: Audit Trail

Every merge must be reversible and attributable:

```sql
create table merge_log (
  id           uuid primary key default gen_random_uuid(),
  winner_id    uuid not null,
  loser_id     uuid not null,
  merged_by    uuid,              -- null if auto-merged
  merged_at    timestamptz default now(),
  confidence   float,             -- matching algorithm score
  snapshot     jsonb not null     -- full loser record at time of merge
);
```

The `snapshot` column stores the complete loser record as JSON. This makes unmerge possible: restore from snapshot, repoint FK references.

## Prevention at Input

The best deduplication is preventing duplicates from entering:

- On insert, run normalization and compute similarity against recent records (last 90 days, same domain/ZIP).
- If confidence > 0.85: block with "This looks like a duplicate of [X]. Add anyway?"
- Log near-duplicate attempts even when the user overrides — useful for later review.
- For imports: deduplicate within the import file first before upserting against the DB.

## Key Rules

- **Normalize into a separate column** — never overwrite user-supplied data.
- Use **blocking** to avoid O(n²) comparisons at scale.
- **Combine multiple similarity scores** — no single algorithm is reliable enough alone.
- **Soft-delete losers with a `merged_into` pointer** — never hard-delete during a merge.
- Store a **full snapshot** of the loser at merge time so merges are reversible.
- Repoint FK references to the winner **atomically in a transaction**.
- Surface near-duplicates **at input time** — cheaper than post-hoc deduplication.
