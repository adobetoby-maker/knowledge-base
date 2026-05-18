# Full-Text Search Ranking

## Why Custom Ranking Matters

The default PostgreSQL full-text search ranks by term frequency alone — a document that mentions "invoice" 20 times outranks a document titled "Invoice Summary" that mentions it once. Users expect title matches to rank higher than body matches, recent content to outrank old content, and their own data to appear before others'. Building a useful ranking function means overriding these defaults deliberately.

## PostgreSQL tsvector / tsquery Fundamentals

```sql
-- Store a pre-computed search vector (faster than recomputing on query)
alter table articles add column search_vector tsvector;

-- Populate with weighted columns: 'A' = title, 'B' = excerpt, 'C' = body
update articles set search_vector =
  setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
  setweight(to_tsvector('english', coalesce(excerpt, '')), 'B') ||
  setweight(to_tsvector('english', coalesce(body, '')), 'C');

-- Keep it current via trigger
create trigger articles_search_vector_update
  before insert or update on articles
  for each row execute function
    tsvector_update_trigger_column(
      search_vector, 'pg_catalog.english', title, excerpt, body
    );

-- GIN index for fast lookup
create index on articles using gin(search_vector);
```

The weight labels A/B/C/D map to 1.0 / 0.4 / 0.2 / 0.1 in `ts_rank`. A match in the title (A) is worth 5× more than a match in the body (C).

## Basic Ranked Query

```sql
select
  id, title,
  ts_rank(search_vector, query, 32) as rank  -- 32 = normalize by document length
from articles,
     websearch_to_tsquery('english', :q) as query
where search_vector @@ query
order by rank desc
limit 20;
```

`websearch_to_tsquery` handles natural language input (stops words, AND/OR/NOT, quoted phrases) — safer and more user-friendly than `to_tsquery` which requires manual operator input.

The normalization flag `32` divides rank by document length — without it, a 10,000-word article about invoices outranks a 100-word article that is only about invoices.

## Boosting Recent Content

Multiply rank by a recency factor that decays over time:

```sql
select
  id, title,
  ts_rank(search_vector, query, 32)
    * (1 + exp(-extract(epoch from (now() - created_at)) / 2592000.0)) as rank
  -- 2592000 = 30 days in seconds; score decays toward baseline over ~30 days
from articles, websearch_to_tsquery('english', :q) as query
where search_vector @@ query
order by rank desc;
```

Tune the decay constant (2592000) to the domain. News content should decay in hours. Documentation should decay over years. A content published today scores ~1.37× higher than one published 30+ days ago with this formula.

## Permission Filtering

Never rank first and filter after — filtering after ranking means you did expensive work on rows the user can't see, and the page count is wrong.

```sql
where search_vector @@ query
  and (tenant_id = :tenantId or is_public = true)  -- filter first
order by rank desc
```

If permission checks are complex (RBAC, row-level rules), materialize a `visible_to_user_ids` array or a `tenant_id` column that can be indexed. A join to a permissions table inside a ranked query kills performance at scale.

## Trigram Fallback for Typos

`tsvector` handles stemming (running → run) but not typos ("invioce" ≠ "invoice"). Add trigram search as a fallback:

```sql
create extension if not exists pg_trgm;
create index on articles using gin(title gin_trgm_ops);

-- In application code: if ts_rank query returns 0 results, fall back to:
select id, title,
  similarity(title, :q) as rank
from articles
where title % :q  -- % = trigram similarity threshold (default 0.3)
order by rank desc
limit 20;
```

Adjust the similarity threshold with `set pg_trgm.similarity_threshold = 0.25` for more permissive typo matching.

A clean implementation runs both queries and merges results: exact/stemmed matches first (higher trust), then trigram matches (marked as "Did you mean X?").

## Search Vector Maintenance

The trigger-based approach above keeps `search_vector` current but fires synchronously on every write — this adds latency to inserts and updates. For write-heavy tables:

1. Remove the trigger.
2. Add `search_vector` to a background update queue (similar to the enrichment queue pattern).
3. A worker updates `search_vector` for changed records every 30–60 seconds.

Acceptable for search (slight indexing lag) — not acceptable for auth or financial data.

## Pagination with Keyset (Not OFFSET)

`OFFSET 100` for page 6 means PostgreSQL scores and sorts all 100 preceding rows, then discards them. Use keyset pagination with rank:

```sql
where search_vector @@ query
  and (ts_rank(search_vector, query) < :last_rank
       or (ts_rank(search_vector, query) = :last_rank and id < :last_id))
order by rank desc, id desc
limit 20;
```

## Key Rules

- Store `search_vector` as a **pre-computed column** with a GIN index — recomputing on every query is too slow.
- **Weight title (A) > excerpt (B) > body (C)** — weight labels, not manual multipliers.
- Use `websearch_to_tsquery`, not `to_tsquery`, for user-supplied queries.
- **Normalize by document length** (flag 32) — prevents long documents from dominating.
- **Filter by permissions before ranking** — not after.
- Use **trigram similarity** (`pg_trgm`) as a fallback for typo-tolerant search.
- Use **keyset pagination** with rank + ID, not OFFSET.
- Tune **recency boost decay constant** to content half-life (news vs docs are very different).
