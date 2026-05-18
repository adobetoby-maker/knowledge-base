# Computing Leaderboard or Product Rankings Nightly

## Why Precompute Rankings

Computing ranks on-the-fly for a leaderboard or trending products requires aggregating, sorting, and ranking potentially millions of rows at query time. For 100k+ records, this adds 500ms–5s to page load. Nightly precomputation reduces the query to a single indexed lookup: `SELECT rank FROM precomputed_ranks WHERE entity_id = $1`.

The tradeoff is staleness: ranks are up to 24 hours behind real-time activity. For most leaderboards and trending lists, this is acceptable. If you need real-time ranking for a live competition, use an incrementally updated sorted set (Redis ZADD) instead.

## Scoring Formula Design

A good ranking score combines multiple signals, weighted by business relevance.

Example for content ranking:
```
score = (likes * 1.0) + (comments * 2.5) + (shares * 4.0) + (views * 0.1)
        * recency_decay(created_at)
```

Recency decay prevents old viral content from permanently occupying top spots:
```js
// Hacker News-style gravity decay
function recencyDecay(createdAt, gravity = 1.8) {
  const ageHours = (Date.now() - createdAt) / 3600000;
  return 1 / Math.pow(ageHours + 2, gravity);
}
```

For product rankings, typical signals: sales volume (last 30 days), review rating × review count, click-through rate, return rate (negative signal).

Document the formula. It will be questioned by stakeholders; having it written down prevents "we changed the algorithm and nobody knew" incidents.

## Tie-Breaking Rules

Ties happen. Without a deterministic tie-breaker, the sort order changes randomly between runs, which looks like a bug.

Always append a stable secondary sort:
1. Primary: computed score (descending)
2. Secondary: created_at (newer items first, as a tiebreaker)
3. Tertiary: entity_id (deterministic lexicographic sort for true ties)

Never leave sort order undefined — `ORDER BY score DESC` without a tiebreaker gives non-deterministic results across DB implementations.

## Percentile Ranks vs Absolute Scores

For user-facing leaderboards, percentile ranks are more motivating than raw scores: "You're in the top 8%" is more actionable than "Score: 1,247."

Compute percentile with a window function:
```sql
SELECT
  user_id,
  score,
  ROUND(
    100.0 * PERCENT_RANK() OVER (ORDER BY score DESC),
    1
  ) AS percentile_rank,
  RANK() OVER (ORDER BY score DESC) AS absolute_rank
FROM user_scores;
```

`PERCENT_RANK()` returns 0 for the top scorer, 1 for the bottom. Invert it: `100.0 - percentile` gives "top X%" framing. `RANK()` gives absolute position with gaps for ties. `DENSE_RANK()` gives position without gaps.

## Caching Computed Ranks

Write results to a dedicated table with a clear timestamp:
```sql
CREATE TABLE computed_ranks (
  entity_id UUID NOT NULL,
  rank_type TEXT NOT NULL,       -- 'leaderboard', 'trending', 'top_products'
  rank_position INT NOT NULL,
  score FLOAT NOT NULL,
  percentile_rank FLOAT,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (entity_id, rank_type)
);
CREATE INDEX ON computed_ranks (rank_type, rank_position);
```

Replace all rows for a `rank_type` atomically using a transaction or `TRUNCATE` + `INSERT`. Don't update row-by-row — partial updates during a running recompute can serve mixed old/new data.

## Incremental vs Full Recompute Tradeoffs

**Full recompute:** Recompute all entity scores from scratch each night. Simple, always correct, handles deleted entities naturally. Viable up to ~1M entities with efficient SQL.

**Incremental recompute:** Recalculate only entities with activity in the past 24 hours. Scales to 10M+ entities. More complex: requires tracking "dirty" entities, handling new vs existing, and separately handling entities that fell out of the top N due to inactivity.

Default to full recompute until it takes >30 minutes. At that point, switch to incremental with a monthly full recompute as a consistency check.

## Key Rules

- Always include a stable tie-breaker (entity_id or created_at) — ties with undefined sort order cause random-looking shuffles.
- Document the scoring formula; treat changes as migrations with a changelog.
- Replace all rows for a rank_type atomically — never update row-by-row while the rank is being read.
- Use `PERCENT_RANK()` for user-facing ranks; "top 8%" is more motivating than a raw score.
- Default to full nightly recompute; switch to incremental only when full recompute exceeds 30 minutes.
- Add `computed_at` to the output table; stale ranks (computed_at > 25h ago) indicate a job failure.
