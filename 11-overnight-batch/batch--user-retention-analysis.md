# Batch: User Retention Analysis Pipeline

## Overview
Retention analysis answers the most important questions in a SaaS product: what percentage of users return after day 1, day 7, and day 30? Where in the user journey do people drop off? Which users are becoming dormant? These answers drive product decisions, but only if the analysis runs automatically and consistently. Manual retention analysis happens once per quarter; automated pipelines run nightly and create the data foundation for proactive re-engagement.

## Implementation

### Retention Cohort Table Schema
```sql
CREATE TABLE retention_cohorts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cohort_date  DATE NOT NULL,          -- the week/month users signed up
  cohort_size  INTEGER NOT NULL,       -- users who signed up in this cohort
  period       INTEGER NOT NULL,       -- 1, 7, 14, 30, 60, 90 (days after signup)
  retained     INTEGER NOT NULL,       -- users still active at this period
  retention_pct NUMERIC(5,2) NOT NULL, -- retained / cohort_size * 100
  computed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (cohort_date, period)
);

-- Dormant users tracking
CREATE TABLE user_activity_summary (
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  last_active_at  TIMESTAMPTZ,
  total_sessions  INTEGER NOT NULL DEFAULT 0,
  day_1_retained  BOOLEAN,
  day_7_retained  BOOLEAN,
  day_30_retained BOOLEAN,
  dormant_since   DATE,               -- set when no activity for 30 days
  re_engaged_at   TIMESTAMPTZ,        -- set when dormant user returns
  PRIMARY KEY (user_id)
);
```

### Cohort Retention Query
```sql
-- Calculate D1/D7/D30 retention for each weekly cohort
INSERT INTO retention_cohorts (cohort_date, cohort_size, period, retained, retention_pct)
SELECT
  cohort.signup_week AS cohort_date,
  cohort.cohort_size,
  retention.period,
  count(DISTINCT s.user_id) AS retained,
  round(100.0 * count(DISTINCT s.user_id) / cohort.cohort_size, 2) AS retention_pct
FROM (
  -- Build cohorts: users grouped by signup week
  SELECT
    date_trunc('week', created_at)::date AS signup_week,
    count(*) AS cohort_size,
    array_agg(id) AS user_ids
  FROM users
  GROUP BY 1
) cohort
CROSS JOIN (
  -- Retention check periods in days
  VALUES (1), (7), (14), (30), (60), (90)
) AS retention(period)
LEFT JOIN sessions s ON
  s.user_id = ANY(cohort.user_ids)
  AND s.created_at >= (cohort.signup_week + retention.period * INTERVAL '1 day')
  AND s.created_at < (cohort.signup_week + (retention.period + 1) * INTERVAL '1 day')
GROUP BY cohort.signup_week, cohort.cohort_size, retention.period
ON CONFLICT (cohort_date, period) DO UPDATE
  SET retained = EXCLUDED.retained,
      retention_pct = EXCLUDED.retention_pct,
      computed_at = now();
```

### Drop-Off Detection
```sql
-- Find the most common last action before churn
-- Users who were active in the last 30-60 days but not in the last 30 days
SELECT
  last_event.event_name,
  count(*) AS user_count,
  round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS pct_of_churned
FROM (
  -- For each churned user, find their last event
  SELECT DISTINCT ON (e.user_id)
    e.user_id,
    e.event_name
  FROM events e
  JOIN users u ON u.id = e.user_id
  WHERE
    -- Active 31-60 days ago
    u.id IN (
      SELECT DISTINCT user_id FROM events
      WHERE created_at BETWEEN NOW() - INTERVAL '60 days' AND NOW() - INTERVAL '31 days'
    )
    -- Not active in last 30 days
    AND u.id NOT IN (
      SELECT DISTINCT user_id FROM events
      WHERE created_at >= NOW() - INTERVAL '30 days'
    )
  ORDER BY e.user_id, e.created_at DESC
) last_event
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;
```

### Dormant User Flagging
```ts
export async function flagDormantUsers() {
  const DORMANT_THRESHOLD_DAYS = 30;
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - DORMANT_THRESHOLD_DAYS);

  // Find users who were active but are now dormant
  await db.query(`
    UPDATE user_activity_summary uas
    SET dormant_since = CURRENT_DATE
    WHERE
      uas.last_active_at < $1
      AND uas.dormant_since IS NULL
      AND uas.last_active_at IS NOT NULL
  `, [cutoff]);

  const newlyDormant = await db.query(`
    SELECT u.id, u.email, u.name, uas.last_active_at
    FROM user_activity_summary uas
    JOIN users u ON u.id = uas.user_id
    WHERE uas.dormant_since = CURRENT_DATE
    ORDER BY uas.last_active_at DESC
  `);

  return newlyDormant.rows;
}
```

### Re-Engagement Segment Export
```ts
export async function buildReEngagementSegments() {
  // Segment 1: Recently dormant (30-45 days) — highest re-engagement potential
  const recentlyDormant = await db.query(`
    SELECT u.id, u.email, u.name,
      uas.last_active_at,
      uas.total_sessions,
      CURRENT_DATE - uas.dormant_since AS days_dormant
    FROM user_activity_summary uas
    JOIN users u ON u.id = uas.user_id
    WHERE uas.dormant_since BETWEEN CURRENT_DATE - INTERVAL '45 days' AND CURRENT_DATE - INTERVAL '30 days'
      AND uas.re_engaged_at IS NULL
    ORDER BY uas.total_sessions DESC  -- prioritize engaged users
    LIMIT 1000
  `);

  // Segment 2: Long dormant (60-90 days) — win-back campaign
  const longDormant = await db.query(`
    SELECT u.id, u.email, u.name, uas.dormant_since
    FROM user_activity_summary uas
    JOIN users u ON u.id = uas.user_id
    WHERE uas.dormant_since BETWEEN CURRENT_DATE - INTERVAL '90 days' AND CURRENT_DATE - INTERVAL '60 days'
      AND uas.re_engaged_at IS NULL
    LIMIT 500
  `);

  // Export to email tool (e.g., via API call)
  await exportSegmentToEmailTool('re-engagement-30-45', recentlyDormant.rows);
  await exportSegmentToEmailTool('winback-60-90', longDormant.rows);

  return {
    recentlyDormantCount: recentlyDormant.rows.length,
    longDormantCount: longDormant.rows.length,
  };
}
```

### Store Results for Trend Comparison
```ts
export async function runRetentionAnalysis() {
  const [cohorts, dormant, segments] = await Promise.all([
    computeCohortRetention(),
    flagDormantUsers(),
    buildReEngagementSegments(),
  ]);

  // Store summary for trend comparison
  await db.query(`
    INSERT INTO retention_run_log (run_date, d1_retention, d7_retention, d30_retention, newly_dormant_count, re_engagement_export_count)
    SELECT
      CURRENT_DATE,
      avg(retention_pct) FILTER (WHERE period = 1),
      avg(retention_pct) FILTER (WHERE period = 7),
      avg(retention_pct) FILTER (WHERE period = 30),
      $1,
      $2
    FROM retention_cohorts
    WHERE cohort_date >= CURRENT_DATE - INTERVAL '90 days'
  `, [dormant.length, segments.recentlyDormantCount + segments.longDormantCount]);
}
```

## Key Rules
- Cohort analysis must use the signup date as the cohort anchor, not arbitrary date ranges — mixing cohorts invalidates comparisons.
- Day-1 retention is the strongest leading indicator of long-term retention — users who return on day 1 are far more likely to stay for 30 days.
- Re-engagement email list must only contain users who have explicitly opted in — dormant users are not a license to spam.
- Drop-off analysis (last action before churn) reveals where the product fails — this is the most actionable insight in the whole pipeline.
- Store previous results for trend comparison — a single retention number is less useful than the trend over 12 weeks.
- Segment by user value (total sessions, subscription tier) before sending re-engagement emails — high-value dormant users deserve more personalized outreach.
- Mark `re_engaged_at` when a dormant user returns — this closes the loop and prevents them from receiving re-engagement emails after returning.
