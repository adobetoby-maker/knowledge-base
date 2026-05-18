# Skill: Record Deduplication

## Overview
Deduplication is necessary whenever data enters from multiple sources (imports, migrations, multiple sign-up flows) or when users create slightly different variations of the same entity. The challenge is that exact-match deduplication misses 70% of real duplicates (different formatting, abbreviations, typos), while overly aggressive fuzzy matching produces false positives (merging distinct but similarly-named records). The correct approach layers multiple strategies: normalize first, block to reduce comparisons, then fuzzy-match within blocks.

## Implementation

### Normalization Functions
Before any comparison, normalize all fields to a canonical form:

```ts
export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export function normalizePhone(phone: string): string {
  // Remove all non-digits, then format as 10-digit US number
  const digits = phone.replace(/\D/g, '');
  if (digits.length === 11 && digits[0] === '1') return digits.slice(1);
  if (digits.length === 10) return digits;
  return digits; // keep as-is if unusual length
}

export function normalizeName(name: string): string {
  return name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, '')  // remove punctuation
    .replace(/\s+/g, ' ');         // collapse whitespace
}

export function normalizeAddress(addr: string): string {
  return addr
    .trim()
    .toLowerCase()
    .replace(/\b(street|st)\b/, 'st')
    .replace(/\b(avenue|ave)\b/, 'ave')
    .replace(/\b(boulevard|blvd)\b/, 'blvd')
    .replace(/[.,#]/g, '')
    .replace(/\s+/g, ' ');
}
```

### Exact Match on Normalized Key
Most duplicates are caught by normalized exact match:

```sql
-- Find duplicate emails after normalization
SELECT
  lower(trim(email)) AS norm_email,
  array_agg(id ORDER BY created_at) AS duplicate_ids,
  count(*) AS count
FROM contacts
GROUP BY lower(trim(email))
HAVING count(*) > 1;
```

### Blocking Strategy
Comparing every record against every other is O(n²) — infeasible for large datasets. Use blocking to limit comparisons to records that share at least one strong signal:

```ts
// Only compare records with the same postal code (blocking key)
// Within each block, do full fuzzy comparison
export async function findDuplicatesWithBlocking(contacts: Contact[]) {
  // Group by blocking key
  const blocks = new Map<string, Contact[]>();

  for (const contact of contacts) {
    const key = contact.postalCode?.slice(0, 5) ?? 'UNKNOWN';
    if (!blocks.has(key)) blocks.set(key, []);
    blocks.get(key)!.push(contact);
  }

  const duplicatePairs: [Contact, Contact][] = [];

  for (const [, block] of blocks) {
    for (let i = 0; i < block.length; i++) {
      for (let j = i + 1; j < block.length; j++) {
        const score = matchScore(block[i], block[j]);
        if (score >= 0.85) {
          duplicatePairs.push([block[i], block[j]]);
        }
      }
    }
  }

  return duplicatePairs;
}
```

### Fuzzy Match Score
```ts
// Jaro-Winkler for names (penalizes differences at the start less)
import jaroWinkler from 'jaro-winkler';

export function matchScore(a: Contact, b: Contact): number {
  const scores: number[] = [];

  // Name similarity (weighted heavily)
  if (a.firstName && b.firstName) {
    scores.push(jaroWinkler(normalizeName(a.firstName), normalizeName(b.firstName)) * 0.4);
  }
  if (a.lastName && b.lastName) {
    scores.push(jaroWinkler(normalizeName(a.lastName), normalizeName(b.lastName)) * 0.4);
  }

  // Phone exact match (strong signal)
  if (a.phone && b.phone && normalizePhone(a.phone) === normalizePhone(b.phone)) {
    scores.push(1.0 * 0.5);
  }

  // Email exact match (strongest signal)
  if (a.email && b.email && normalizeEmail(a.email) === normalizeEmail(b.email)) {
    scores.push(1.0 * 0.6);
  }

  return scores.length > 0 ? Math.min(scores.reduce((s, v) => s + v, 0), 1.0) : 0;
}
```

### Merge Survivor Selection
When merging two records, choose the survivor by completeness:

```ts
export function selectSurvivor(records: Contact[]): Contact {
  // Score each record by field completeness
  const completeness = (r: Contact) => {
    const fields = ['email', 'phone', 'firstName', 'lastName', 'company', 'address'];
    return fields.filter(f => r[f as keyof Contact]).length;
  };

  // Use the most complete record as the base
  const base = records.sort((a, b) => completeness(b) - completeness(a))[0];

  // Fill in missing fields from other records
  const merged = { ...base };
  for (const record of records) {
    for (const [key, value] of Object.entries(record)) {
      if (!merged[key as keyof Contact] && value) {
        (merged as any)[key] = value;
      }
    }
  }

  return merged;
}
```

### Audit Trail for Merges
```ts
export async function mergeDuplicates(survivorId: string, mergedIds: string[]) {
  await db.transaction(async (tx) => {
    // Reassign related records
    await tx.query(
      'UPDATE orders SET contact_id = $1 WHERE contact_id = ANY($2)',
      [survivorId, mergedIds]
    );

    // Log the merge
    await tx.query(
      `INSERT INTO merge_audit (survivor_id, merged_ids, merged_at, merged_by)
       VALUES ($1, $2, now(), $3)`,
      [survivorId, mergedIds, currentUserId]
    );

    // Soft-delete the merged records (don't hard delete — enables rollback)
    await tx.query(
      'UPDATE contacts SET deleted_at = now(), merged_into = $1 WHERE id = ANY($2)',
      [survivorId, mergedIds]
    );
  });
}
```

## Key Rules
- Normalize before comparing — unnormalized exact match misses most real duplicates.
- Use blocking (group by postal code, name initial, etc.) before fuzzy matching — full O(n²) comparison is infeasible beyond 10k records.
- Jaro-Winkler is better than Levenshtein for name matching — it handles transpositions and prioritizes prefix matches.
- Email exact match (after normalization) is the strongest deduplication signal — treat it as near-definitive.
- Never hard-delete merged records immediately — soft-delete with `merged_into` reference enables rollback.
- Store a merge audit record for every merge with the actor, timestamp, and which records were consumed.
- Human review queue for matches with scores between 0.7–0.85 — high confidence auto-merges; borderline cases need eyes.
