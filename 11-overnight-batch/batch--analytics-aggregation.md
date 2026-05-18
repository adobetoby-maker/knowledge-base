# Batch Job: Analytics Aggregation

## Overview

Roll up raw event data into pre-aggregated tables for dashboard queries. Raw events tables grow unboundedly and are slow to aggregate at query time. Nightly aggregation into day/week/month buckets makes dashboard queries fast and predictable. Run the aggregation job nightly after midnight for the previous day.

## Raw Events Table

```sql
CREATE TABLE page_views (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  page_path  TEXT NOT NULL,
  user_id    UUID REFERENCES users(id),
  session_id TEXT NOT NULL,
  country    TEXT,
  referrer   TEXT,
  viewed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Partition by month for manageable table size
CREATE TABLE page_views_2024_08 PARTITION OF page_views
  FOR VALUES FROM ('2024-08-01') TO ('2024-09-01');

CREATE INDEX pv_path_viewed ON page_views(page_path, viewed_at DESC);
CREATE INDEX pv_viewed_date ON page_views(date_trunc('day', viewed_at));
```

## Daily Aggregation

```ts
async function aggregateDailyPageViews(date: Date): Promise<void> {
  const dateStr = format(date, 'yyyy-MM-dd')

  // Check if already aggregated (idempotent)
  const existing = await db.query.pageViewsDailySummary.findFirst({
    where: eq(pageViewsDailySummary.date, dateStr),
  })
  if (existing) {
    logger.info({ date: dateStr }, 'Daily aggregation already complete')
    return
  }

  await db.execute(sql`
    INSERT INTO page_views_daily_summary (date, page_path, views, unique_visitors, unique_sessions)
    SELECT
      ${dateStr}::date AS date,
      page_path,
      COUNT(*) AS views,
      COUNT(DISTINCT user_id) AS unique_visitors,
      COUNT(DISTINCT session_id) AS unique_sessions
    FROM page_views
    WHERE viewed_at >= ${startOfDay(date)}
      AND viewed_at < ${endOfDay(date)}
    GROUP BY page_path
    ON CONFLICT (date, page_path) DO UPDATE
      SET views = EXCLUDED.views,
          unique_visitors = EXCLUDED.unique_visitors,
          unique_sessions = EXCLUDED.unique_sessions,
          updated_at = now()
  `)

  logger.info({ date: dateStr }, 'Daily page view aggregation complete')
}
```

## Weekly and Monthly Rollup

```ts
async function aggregateWeeklyStats(weekStart: Date): Promise<void> {
  await db.execute(sql`
    INSERT INTO page_views_weekly_summary (week_start, page_path, views, unique_visitors)
    SELECT
      ${format(weekStart, 'yyyy-MM-dd')}::date AS week_start,
      page_path,
      SUM(views) AS views,
      SUM(unique_visitors) AS unique_visitors  -- Approximate, not distinct across days
    FROM page_views_daily_summary
    WHERE date >= ${format(weekStart, 'yyyy-MM-dd')}::date
      AND date < ${format(addDays(weekStart, 7), 'yyyy-MM-dd')}::date
    GROUP BY page_path
    ON CONFLICT (week_start, page_path) DO UPDATE
      SET views = EXCLUDED.views,
          unique_visitors = EXCLUDED.unique_visitors
  `)
}
```

## Revenue Aggregation

```ts
async function aggregateDailyRevenue(date: Date): Promise<void> {
  const dateStr = format(date, 'yyyy-MM-dd')

  await db.execute(sql`
    INSERT INTO revenue_daily (date, revenue_cents, order_count, avg_order_cents, new_customers)
    SELECT
      ${dateStr}::date,
      SUM(total_cents)::INTEGER AS revenue_cents,
      COUNT(*)::INTEGER AS order_count,
      AVG(total_cents)::INTEGER AS avg_order_cents,
      COUNT(DISTINCT CASE WHEN u.created_at >= ${startOfDay(date)} THEN o.user_id END)::INTEGER AS new_customers
    FROM orders o
    JOIN users u ON o.user_id = u.id
    WHERE o.status = 'paid'
      AND o.paid_at >= ${startOfDay(date)}
      AND o.paid_at < ${endOfDay(date)}
    ON CONFLICT (date) DO UPDATE
      SET revenue_cents = EXCLUDED.revenue_cents,
          order_count = EXCLUDED.order_count,
          avg_order_cents = EXCLUDED.avg_order_cents,
          new_customers = EXCLUDED.new_customers
  `)
}
```

## Dashboard Query (Fast with Aggregates)

```ts
// With aggregates: instant query
async function getDashboardStats(days = 30) {
  const since = subDays(new Date(), days)

  const [revenue, pageViews] = await Promise.all([
    db.execute(sql`
      SELECT
        SUM(revenue_cents) AS total_revenue,
        SUM(order_count) AS total_orders,
        AVG(revenue_cents) AS avg_daily_revenue
      FROM revenue_daily
      WHERE date >= ${format(since, 'yyyy-MM-dd')}
    `),
    db.execute(sql`
      SELECT
        SUM(views) AS total_views,
        SUM(unique_sessions) AS total_sessions
      FROM page_views_daily_summary
      WHERE date >= ${format(since, 'yyyy-MM-dd')}
    `),
  ])

  return {
    totalRevenue: Number(revenue[0].total_revenue ?? 0),
    totalOrders: Number(revenue[0].total_orders ?? 0),
    totalPageViews: Number(pageViews[0].total_views ?? 0),
  }
}
```

## Job Runner

```ts
async function runNightlyAggregations(): Promise<void> {
  const yesterday = subDays(startOfDay(new Date()), 1)

  const jobs = [
    { name: 'page-views-daily', fn: () => aggregateDailyPageViews(yesterday) },
    { name: 'revenue-daily', fn: () => aggregateDailyRevenue(yesterday) },
    // Run weekly on Mondays
    ...(isMonday(new Date()) ? [{ name: 'page-views-weekly', fn: () => aggregateWeeklyStats(startOfWeek(yesterday)) }] : []),
  ]

  for (const job of jobs) {
    const start = Date.now()
    try {
      await job.fn()
      logger.info({ job: job.name, ms: Date.now() - start }, 'Aggregation complete')
    } catch (err) {
      logger.error({ job: job.name, err }, 'Aggregation failed')
    }
  }
}
```

## Key Rules

- Use `ON CONFLICT DO UPDATE` for idempotent aggregation — re-running for the same date updates correctly.
- Aggregate the previous full day (not today) — partial-day aggregates are misleading in dashboards.
- Store raw events in partitioned tables — monthly partitions let you `DROP PARTITION` to archive old data cheaply.
- Don't sum `unique_visitors` across days to get weekly uniques — they're not additive. Use HyperLogLog or exact daily/weekly counts separately.
- Schedule aggregation at 2-3AM in the site's primary timezone — after midnight in the least-active timezone.
