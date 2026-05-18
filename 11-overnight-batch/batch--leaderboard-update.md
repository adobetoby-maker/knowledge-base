# Batch: Nightly Leaderboard Update

## What This Covers

Computing rankings from activity events, assigning percentile ranks, refreshing a materialized view for the top-N leaderboard, and sending delta notifications to users who moved significantly in the rankings.

## Why Compute Rankings Nightly (Not in Real Time)

Computing ranks in real time requires querying and sorting all users on every request. For a leaderboard of 100,000 users, that is an expensive `ORDER BY score DESC` with a `ROW_NUMBER()` window function on every page load — even with indexes.

The nightly batch computes ranks once and stores them. The UI reads a precomputed table. This trades freshness (ranks are up to 24 hours stale) for query performance (single row lookup). For most leaderboards, 24-hour freshness is acceptable; for live gaming leaderboards, use Redis sorted sets instead.

## Score Computation from Activity Events

Scores should derive from immutable event tables, not mutable counters. This means you can always recompute from scratch, and the score formula can evolve without migrating historical data.

```ts
async function computeUserScores(since: Date): Promise<Map<string, number>> {
  // Example: XP scoring from language learning activity events
  const events = await db.query(`
    SELECT user_id, event_type, metadata, created_at
    FROM activity_events
    WHERE created_at >= $1
  `, [since])
  
  const POINT_VALUES: Record<string, number> = {
    'lesson_completed': 10,
    'quiz_passed': 25,
    'streak_maintained': 5,
    'vocabulary_reviewed': 2,
    'tutor_session': 50,
  }
  
  const scores = new Map<string, number>()
  
  for (const event of events.rows) {
    const points = POINT_VALUES[event.event_type] ?? 0
    scores.set(event.user_id, (scores.get(event.user_id) ?? 0) + points)
  }
  
  return scores
}
```

Scores can be cumulative (all-time) or windowed (last 30 days). Store both in the rankings table and let the UI choose. Windowed rankings keep the leaderboard competitive — all-time rankings calcify once early adopters build insurmountable leads.

## Ranking and Percentile Computation

```ts
async function updateRankings() {
  const today = new Date().toISOString().split('T')[0]
  
  // Compute all-time scores + rank + percentile in one query
  await db.query(`
    INSERT INTO leaderboard_snapshots (date, user_id, score, rank, percentile)
    SELECT
      $1 AS date,
      user_id,
      total_xp AS score,
      ROW_NUMBER() OVER (ORDER BY total_xp DESC) AS rank,
      ROUND(
        100.0 * (1 - (ROW_NUMBER() OVER (ORDER BY total_xp DESC) - 1)::float / NULLIF(COUNT(*) OVER () - 1, 0)),
        1
      ) AS percentile
    FROM user_stats
    WHERE total_xp > 0
    ON CONFLICT (date, user_id) DO UPDATE
      SET score = EXCLUDED.score, rank = EXCLUDED.rank, percentile = EXCLUDED.percentile
  `, [today])
}
```

Percentile: a user in the 95th percentile scored higher than 95% of users. Formula: `100 * (1 - (rank - 1) / (total - 1))`. User at rank 1 is 100th percentile; user at rank N is 0th percentile (approximately).

## Top-N Materialized View

The leaderboard page typically shows top 100 users. Refresh a materialized view so the leaderboard query is a simple `SELECT * FROM top_leaderboard`:

```sql
CREATE MATERIALIZED VIEW top_leaderboard AS
SELECT
  u.id, u.display_name, u.avatar_url,
  ls.score, ls.rank, ls.percentile
FROM leaderboard_snapshots ls
JOIN users u ON ls.user_id = u.id
WHERE ls.date = CURRENT_DATE
  AND ls.rank <= 100
ORDER BY ls.rank ASC;

CREATE UNIQUE INDEX ON top_leaderboard (id);
```

Refresh in the nightly job after computing all rankings:

```ts
await db.query('REFRESH MATERIALIZED VIEW CONCURRENTLY top_leaderboard')
```

`CONCURRENTLY` allows reads during the refresh (requires the unique index). Without it, the view is locked during refresh, blocking the leaderboard page.

## Delta Notifications

Notify users who moved significantly — e.g., entered the top 10, crossed a percentile milestone, or jumped more than 50 rank positions.

```ts
async function sendRankDeltaNotifications(today: string, yesterday: string) {
  const deltas = await db.query(`
    SELECT
      t.user_id,
      t.rank AS rank_today,
      y.rank AS rank_yesterday,
      t.percentile AS percentile_today,
      y.percentile AS percentile_yesterday,
      (y.rank - t.rank) AS rank_improvement  -- positive = moved up
    FROM leaderboard_snapshots t
    JOIN leaderboard_snapshots y ON t.user_id = y.user_id
    WHERE t.date = $1 AND y.date = $2
      AND (
        (t.rank <= 10 AND y.rank > 10) OR          -- entered top 10
        (y.rank - t.rank) >= 50 OR                  -- jumped 50+ positions
        (floor(t.percentile / 10) > floor(y.percentile / 10))  -- crossed percentile tier
      )
  `, [today, yesterday])
  
  for (const delta of deltas.rows) {
    await pushNotification(delta.user_id, buildRankMessage(delta))
  }
}

function buildRankMessage(delta: RankDelta): string {
  if (delta.rank_today <= 10 && delta.rank_yesterday > 10) {
    return `You entered the top 10! You're now ranked #${delta.rank_today}.`
  }
  if (delta.rank_improvement >= 50) {
    return `You jumped ${delta.rank_improvement} spots! Now ranked #${delta.rank_today}.`
  }
  return `You're now in the top ${100 - Math.floor(delta.percentile_today)}% of learners!`
}
```

Only send positive delta notifications (moved up). Notifying users they dropped in rank creates a negative experience with no actionable next step.

## Key Rules

- Compute scores from immutable event tables so rankings can always be recomputed from scratch
- Store both cumulative and windowed (e.g., 30-day) scores — windowed rankings keep competition alive
- Use `ROW_NUMBER() OVER (ORDER BY score DESC)` in a single query — do not rank in application code
- Refresh the materialized view with `CONCURRENTLY` to avoid locking the leaderboard page during refresh
- Only notify users of positive rank changes (moved up, crossed a milestone) — never notify drops
- Cap delta notifications to significant jumps to avoid flooding active users with notifications
- Retain daily snapshots for at least 90 days for trend display and analytics
