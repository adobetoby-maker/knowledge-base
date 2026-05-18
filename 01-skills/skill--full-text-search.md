# Skill: Full-Text Search Implementation

## What This Covers

PostgreSQL full-text search beyond basic `tsvector`: column weighting for relevance tuning, trigram extension for fuzzy/partial matching, result ranking and scoring, highlighting matched terms in the UI, and a decision framework for when native DB search is sufficient vs when to reach for Algolia.

## Why Weighted Columns Matter

Not all fields are equally relevant. A match in a product title should outrank a match in the description body. PostgreSQL's `setweight` function assigns A/B/C/D weights to different `tsvector` components. The `ts_rank` function then uses these weights when scoring results.

```sql
-- Generate a weighted tsvector combining multiple columns
ALTER TABLE products ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(name, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(sku, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'C') ||
    setweight(to_tsvector('english', coalesce(tags, '')), 'B')
  ) STORED;

CREATE INDEX products_search_idx ON products USING GIN (search_vector);
```

Weight A has the highest score impact, D the lowest. Matches in `name` will rank higher than identical matches in `description` automatically.

```sql
-- Query with ranking
SELECT
  id, name, description,
  ts_rank(search_vector, query) AS rank
FROM products,
  websearch_to_tsquery('english', 'wireless headphones') AS query
WHERE search_vector @@ query
ORDER BY rank DESC
LIMIT 20;
```

## Trigram Extension for Fuzzy Matching

`tsvector` only matches whole words (with stemming). It won't find "PostgreSQL" if someone types "Postgres" or handle typos like "headphnes". The `pg_trgm` extension enables similarity matching and trigram indexes, which support partial prefix matching and fuzzy lookups.

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Add trigram index alongside the GIN search index
CREATE INDEX products_name_trgm_idx ON products USING GIN (name gin_trgm_ops);

-- Fuzzy search: finds rows where similarity > threshold
SELECT id, name, similarity(name, 'headphnes') AS sim
FROM products
WHERE name % 'headphnes'  -- % operator uses similarity threshold (default 0.3)
ORDER BY sim DESC
LIMIT 10;
```

Combine the two: use `tsvector` for primary full-text ranking, fall back to trigram similarity when FTS returns 0 results. This covers both "searched correctly but for a rare term" and "typo in the search query".

## Highlighting Matched Terms (Server Side)

PostgreSQL's `ts_headline` generates an excerpt with matched terms wrapped in markup. This is more accurate than client-side regex highlighting because it understands stemming (searching "running" also highlights "ran").

```sql
SELECT
  id,
  ts_headline(
    'english',
    description,
    websearch_to_tsquery('english', 'wireless headphones'),
    'StartSel=<mark>, StopSel=</mark>, MaxWords=30, MinWords=15, ShortWord=3'
  ) AS excerpt
FROM products
WHERE search_vector @@ websearch_to_tsquery('english', 'wireless headphones');
```

`ts_headline` is slow — do not call it on unfiltered rows. Only apply it to the final result set (after `WHERE` and `LIMIT`).

## Pagination with Ranked Results

Ranked search results cannot use simple cursor pagination (you can't cursor on rank since it changes between queries). Use offset pagination for ranked search, but cap the depth (e.g., max page 10) — deep pagination of ranked results is slow and rarely useful in practice.

```ts
const { data } = await supabase.rpc('search_products', {
  query_text: query,
  page_size: 20,
  page_offset: (page - 1) * 20,
})
```

Define this as a Postgres function to avoid exposing raw SQL through the API.

## When to Use Algolia vs PostgreSQL FTS

**Stay with PostgreSQL FTS when:**
- Dataset is under ~5M rows with reasonable indexing
- Search is a secondary feature, not a primary product interaction
- You need search results to be transactionally consistent with writes (no sync lag)
- Budget matters — Algolia adds meaningful cost at scale
- Queries are simple keyword matching without complex synonyms or analytics

**Move to Algolia (or similar) when:**
- Search is the primary user interaction (e-commerce catalog, docs site)
- You need synonyms, typo tolerance, and faceted filtering with real-time analytics
- Search needs to stay fast across tens of millions of records without DBA tuning
- You need A/B testing of search ranking or personalization
- The replication lag is acceptable (Algolia index is eventually consistent with your DB)

The hidden cost of Algolia: you now have two sources of truth. Any schema change in your DB requires an index re-sync. Writes must update both Postgres and Algolia atomically (or use a background sync worker). Postgres FTS eliminates this coupling.

## Key Rules

- Use `setweight` to give title/name fields higher rank than description/body fields
- Add `pg_trgm` as a fallback for partial matches and typos — FTS alone is too strict
- Call `ts_headline` only on the paginated result set, never on unfiltered rows
- Use `websearch_to_tsquery` instead of `plainto_tsquery` — it handles user-typed queries naturally (quotes, minus signs)
- Cap ranked search pagination at ~10 pages — deeper ranks are low signal and slow
- Prefer PostgreSQL FTS for internal/consistency-critical search; use Algolia when search is the core product value
- Keep a single `search_vector` generated column per table — do not concatenate at query time (bypasses the index)
