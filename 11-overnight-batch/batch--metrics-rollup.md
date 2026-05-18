# Batch: Metrics Aggregation and Rollup

## Overview
Dashboard queries that scan raw event tables are slow, expensive, and non-scalable. A product that tracks user events, page views, and transactions accumulates tens of millions of rows within months. Rolling up raw data into pre-aggregated hourly and daily summaries makes dashboard queries 100–1000x faster. The nightly rollup generates daily aggregates from hourly ones; separate hourly rollups run on a shorter schedule. Historical backfills and schema changes are handled without losing data.

## Implementation

### Rollup Table Schema
```sql
-- Daily metrics rollup (one row per day per dimension combination)
CREATE TABLE metrics_daily (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date        DATE NOT NULL,
  metric      TEXT NOT NULL,          -- e.g., 'page_views', 'signups', 'revenue'
  dimension   TEXT,                   -- e.g., 'source', 'plan', 'country'
  dim_value   TEXT,                   -- e.g., 'organic', 'pro', 'US'
  value       NUMERIC NOT NULL,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (date, metric, dimension, dim_value)
);

CREATE INDEX ON metrics_daily (metric, date DESC);
CREATE INDEX ON metrics_daily (date DESC, metric, dimension);

-- Hourly rollup (for near-real-time dashboards)
CREATE TABLE metrics_hourly (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hour        TIMESTAMPTZ NOT NULL,   -- truncated to the hour
  metric      TEXT NOT NULL,
  dimension   TEXT,
  dim_value   TEXT,
  value       NUMERIC NOT NULL,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (hour, metric, dimension, dim_value)
);
```

### Hourly Rollup (Runs Every Hour)
```sql
-- Roll up page views for the last completed hour
INSERT INTO metrics_hourly (hour, metric, dimension, dim_value, value)
SELECT
  date_trunc('hour', created_at) AS hour,
  'page_views' AS metric,
  'source' AS dimension,
  COALESCE(utm_source, 'direct') AS dim_value,
  count(*) AS value
FROM page_views
WHERE created_at >= date_trunc('hour', NOW() - INTERVAL '1 hour')
  AND created_at < date_trunc('hour', NOW())
GROUP BY 1, 3, 4
ON CONFLICT (hour, metric, dimension, dim_value)
  DO UPDATE SET value = EXCLUDED.value, computed_at = now();
```

### Daily Rollup from Hourly (Nightly at 1:00 AM)
```sql
-- Aggregate hourly → daily for yesterday
INSERT INTO metrics_daily (date, metric, dimension, dim_value, value)
SELECT
  date_trunc('day', hour)::date AS date,
  metric,
  dimension,
  dim_value,
  SUM(value) AS value     -- sum for counts; use AVG for rates
FROM metrics_hourly
WHERE hour >= CURRENT_DATE - INTERVAL '1 day'
  AND hour < CURRENT_DATE
GROUP BY 1, 2, 3, 4
ON CONFLICT (date, metric, dimension, dim_value)
  DO UPDATE SET value = EXCLUDED.value, computed_at = now();
```

### TypeScript Orchestrator
```ts
export async function runMetricsRollup(date: Date = new Date()) {
  const yesterday = new Date(date);
  yesterday.setDate(yesterday.getDate() - 1);
  const dateStr = yesterday.toISOString().split('T')[0];

  const metrics = [
    { name: 'page_views', query: pageViewsRollup },
    { name: 'signups', query: signupsRollup },
    { name: 'revenue', query: revenueRollup },
    { name: 'active_users', query: activeUsersRollup },
    { name: 'api_calls', query: apiCallsRollup },
  ];

  const results = [];

  for (const metric of metrics) {
    const start = Date.now();
    try {
      const rows = await db.query(metric.query, [dateStr]);
      results.push({
        metric: metric.name,
        rowsWritten: rows.rowCount,
        durationMs: Date.now() - start,
        status: 'success',
      });
    } catch (err) {
      results.push({
        metric: metric.name,
        error: (err as Error).message,
        status: 'failed',
      });
    }
  }

  // Store rollup run metadata
  await db.query(`
    INSERT INTO metrics_rollup_runs (run_date, results, completed_at)
    VALUES ($1, $2, now())
  `, [dateStr, JSON.stringify(results)]);

  return results;
}
```

### Revenue Rollup (with Multiple Dimensions)
```sql
INSERT INTO metrics_daily (date, metric, dimension, dim_value, value)
SELECT
  $1::date AS date,
  'revenue' AS metric,
  'plan' AS dimension,
  p.name AS dim_value,
  SUM(t.amount_cents) / 100.0 AS value
FROM transactions t
JOIN subscriptions s ON s.id = t.subscription_id
JOIN plans p ON p.id = s.plan_id
WHERE t.created_at::date = $1
  AND t.status = 'succeeded'
GROUP BY p.name
ON CONFLICT (date, metric, dimension, dim_value)
  DO UPDATE SET value = EXCLUDED.value, computed_at = now();
```

### Backfill Command
When schema changes require historical recomputation:
```ts
export async function backfillMetrics(startDate: Date, endDate: Date) {
  const current = new Date(startDate);

  while (current < endDate) {
    const dateStr = current.toISOString().split('T')[0];
    console.log(`Backfilling ${dateStr}...`);
    await runMetricsRollup(current);
    current.setDate(current.getDate() + 1);
  }
}
```

### Dashboard Query (Uses Rollup, Not Raw Events)
```ts
// Fast: queries pre-aggregated rollup table
async function getDailyRevenue(startDate: string, endDate: string): Promise<DailyMetric[]> {
  return db.query(`
    SELECT date, SUM(value) AS total_revenue
    FROM metrics_daily
    WHERE metric = 'revenue'
      AND date BETWEEN $1 AND $2
    GROUP BY date
    ORDER BY date
  `, [startDate, endDate]);
}

// Slow: scans raw transactions — DON'T use for dashboards
// SELECT date_trunc('day', created_at)::date, SUM(amount_cents) FROM transactions WHERE ...
```

## Key Rules
- Use `ON CONFLICT DO UPDATE` for idempotency — rollups must be rerunnable without creating duplicates.
- Separate hourly and daily rollup tables — dashboards for different time ranges query different tables.
- Dashboard queries must use rollup tables, not raw event tables — raw table scans kill performance at scale.
- Backfill command is essential — any rollup schema change requires rebuilding history.
- Store rollup run metadata (date, rows written, duration) — this enables detecting when a rollup was missed.
- For ratios (conversion rate), store numerator and denominator as separate metrics, not the computed ratio — recompute the ratio at query time to avoid precision issues on partial data.
- Rollup queries should process exactly one day's data at a time — processing multiple days in one query makes failure recovery harder.
