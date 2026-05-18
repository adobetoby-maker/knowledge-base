# Skill: Analytics Dashboard

## Overview

An analytics dashboard aggregates metrics and displays them in charts. The key design decisions: pre-aggregate data at write time (for performance) vs compute at query time (for flexibility), use time-series queries with proper interval bucketing, and handle timezone offsets correctly.

## Schema Design

```sql
-- Raw events table (append-only)
CREATE TABLE events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES users(id),
  event_type  text NOT NULL,           -- 'page_view', 'click', 'signup'
  properties  jsonb DEFAULT '{}',
  occurred_at timestamptz NOT NULL DEFAULT now()
);

-- Partitioned for performance at scale
CREATE TABLE events (
  ...
) PARTITION BY RANGE (occurred_at);

CREATE TABLE events_2026_05 PARTITION OF events
  FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- Pre-aggregated daily stats
CREATE TABLE daily_stats (
  date        date NOT NULL,
  metric      text NOT NULL,          -- 'page_views', 'signups', 'revenue_cents'
  value       bigint NOT NULL,
  created_at  timestamptz DEFAULT now(),
  PRIMARY KEY (date, metric)
);
```

## Time-Series Query

```ts
// Get daily metrics for a date range
async function getDailyMetrics(metric: string, startDate: Date, endDate: Date) {
  // Use generate_series to include days with no data (zero-fill gaps)
  const rows = await db.execute(sql`
    WITH date_range AS (
      SELECT generate_series(
        ${startDate}::date,
        ${endDate}::date,
        '1 day'::interval
      )::date AS date
    )
    SELECT
      dr.date,
      COALESCE(ds.value, 0) AS value
    FROM date_range dr
    LEFT JOIN daily_stats ds
      ON ds.date = dr.date AND ds.metric = ${metric}
    ORDER BY dr.date
  `)

  return rows as { date: string; value: number }[]
}
```

Without `generate_series`, days with zero activity don't appear in results — charts show misleading gaps.

## Aggregating Event Counts

```ts
// Query raw events grouped by interval
async function getEventCounts(eventType: string, interval: 'hour' | 'day' | 'week', days: number) {
  const truncFn = interval === 'hour' ? 'hour' : interval === 'week' ? 'week' : 'day'

  return db.execute(sql`
    SELECT
      date_trunc(${truncFn}, occurred_at AT TIME ZONE 'UTC') AS bucket,
      COUNT(*) AS count
    FROM events
    WHERE event_type = ${eventType}
      AND occurred_at >= now() - ${days} * interval '1 day'
    GROUP BY bucket
    ORDER BY bucket
  `)
}
```

Always convert to a consistent timezone for bucketing — mixing server timezone and UTC produces incorrect day boundaries.

## KPI Cards

```tsx
interface KpiCard {
  label: string
  value: number
  previousValue: number
  format: 'number' | 'currency' | 'percent'
}

function KpiCard({ label, value, previousValue, format }: KpiCard) {
  const change = previousValue > 0 ? ((value - previousValue) / previousValue) * 100 : 0
  const isPositive = change >= 0

  const formatted = format === 'currency'
    ? formatCents(value)
    : format === 'percent'
    ? `${value.toFixed(1)}%`
    : value.toLocaleString()

  return (
    <div className="p-6 bg-white rounded-lg border">
      <p className="text-sm text-gray-500 mb-1">{label}</p>
      <p className="text-3xl font-bold">{formatted}</p>
      <p className={`text-sm mt-1 ${isPositive ? 'text-green-600' : 'text-red-600'}`}>
        {isPositive ? '↑' : '↓'} {Math.abs(change).toFixed(1)}% vs prior period
      </p>
    </div>
  )
}
```

## Date Range Picker

```tsx
type DateRange = { start: Date; end: Date }
type Preset = '7d' | '30d' | '90d' | 'custom'

function DateRangePicker({ value, onChange }: { value: DateRange; onChange: (r: DateRange) => void }) {
  function applyPreset(preset: Preset) {
    const end = new Date()
    end.setHours(23, 59, 59, 999)
    const start = new Date()
    if (preset === '7d') start.setDate(start.getDate() - 7)
    if (preset === '30d') start.setDate(start.getDate() - 30)
    if (preset === '90d') start.setDate(start.getDate() - 90)
    start.setHours(0, 0, 0, 0)
    onChange({ start, end })
  }

  return (
    <div className="flex gap-2">
      {(['7d', '30d', '90d'] as const).map(p => (
        <button key={p} onClick={() => applyPreset(p)} className="px-3 py-1 text-sm border rounded hover:bg-gray-50">
          Last {p}
        </button>
      ))}
    </div>
  )
}
```

## Comparison Period

```ts
// Compare current period to same-length prior period
function getPriorPeriod(start: Date, end: Date): { start: Date; end: Date } {
  const durationMs = end.getTime() - start.getTime()
  return {
    start: new Date(start.getTime() - durationMs),
    end: new Date(end.getTime() - durationMs),
  }
}
```

## Key Rules

- Always use `generate_series` to zero-fill gaps — a chart with missing days implies "no data" not "zero" to users.
- Pre-aggregate on a cron job for dashboards accessed frequently — computing over 90 days of raw events on every page load is too slow.
- Apply timezone offset before date bucketing — `AT TIME ZONE user_tz` must come before `date_trunc`.
- Show comparison period change (% vs prior period) on every KPI card — absolute numbers without context are less useful.
- Cache expensive metric queries with a short TTL (5–15 min) — dashboards don't need real-time data.
