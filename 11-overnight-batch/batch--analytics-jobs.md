# Batch: Analytics Jobs

## Overview

Daily analytics aggregation jobs that pre-compute summaries into reporting tables. Running analytics queries against live tables at report time is slow and locks rows. Precompute instead.

## Why Precompute

Analytics queries are expensive: aggregations over large tables, multi-table joins, complex time windows. Running them in response to a dashboard request means:
- Dashboard load time measured in seconds, not milliseconds
- Production database load spikes on dashboard views
- Complex queries compete with write operations for I/O

Precompute overnight into summary tables. Dashboard reads become simple `SELECT * WHERE date = today` queries.

## Schema: Summary Tables

```sql
-- Daily revenue summary
CREATE TABLE daily_revenue_summary (
  date          DATE NOT NULL,
  total_cents   BIGINT NOT NULL DEFAULT 0,
  order_count   INTEGER NOT NULL DEFAULT 0,
  avg_cents     BIGINT GENERATED ALWAYS AS (
    CASE WHEN order_count > 0 THEN total_cents / order_count ELSE 0 END
  ) STORED,
  new_customers INTEGER NOT NULL DEFAULT 0,
  refunds_cents BIGINT NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (date)
);

-- Service popularity summary
CREATE TABLE monthly_service_stats (
  month        DATE NOT NULL,  -- First day of month
  service_name TEXT NOT NULL,
  count        INTEGER NOT NULL DEFAULT 0,
  revenue_cents BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (month, service_name)
);
```

## Aggregation Script

```ts
// scripts/aggregate-analytics.ts
import { createClient } from '@supabase/supabase-js'
import { startOfDay, endOfDay, format, subDays } from 'date-fns'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
)

async function aggregateDailyRevenue(date: Date): Promise<void> {
  const start = startOfDay(date).toISOString()
  const end = endOfDay(date).toISOString()

  // Query raw data
  const { data: orders } = await supabase
    .from('orders')
    .select('total_cents, customer_id, created_at, status')
    .gte('created_at', start)
    .lt('created_at', end)
    .in('status', ['completed', 'refunded'])

  if (!orders) return

  const completed = orders.filter((o) => o.status === 'completed')
  const refunded = orders.filter((o) => o.status === 'refunded')

  // Unique customer IDs not seen before today
  const customerIds = [...new Set(completed.map((o) => o.customer_id))]
  const { count: existingCustomers } = await supabase
    .from('orders')
    .select('customer_id', { count: 'exact', head: true })
    .in('customer_id', customerIds)
    .lt('created_at', start)

  const newCustomers = customerIds.length - (existingCustomers ?? 0)

  const summary = {
    date: format(date, 'yyyy-MM-dd'),
    total_cents: completed.reduce((sum, o) => sum + o.total_cents, 0),
    order_count: completed.length,
    new_customers: newCustomers,
    refunds_cents: refunded.reduce((sum, o) => sum + o.total_cents, 0),
  }

  await supabase
    .from('daily_revenue_summary')
    .upsert(summary, { onConflict: 'date' })

  console.log(`Aggregated ${format(date, 'yyyy-MM-dd')}: ${completed.length} orders, $${summary.total_cents / 100}`)
}

// Main: aggregate yesterday (run at 2am)
const yesterday = subDays(new Date(), 1)
await aggregateDailyRevenue(yesterday)

// Optionally backfill last 7 days to correct any gaps
for (let i = 1; i <= 7; i++) {
  await aggregateDailyRevenue(subDays(new Date(), i))
}

console.log('Analytics aggregation complete')
process.exit(0)
```

## Supabase SQL Approach (Alternative)

For Postgres-native aggregation, use a SQL function called via the job:

```sql
CREATE OR REPLACE FUNCTION aggregate_daily_revenue(p_date DATE)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO daily_revenue_summary (date, total_cents, order_count, new_customers, refunds_cents)
  SELECT
    p_date,
    COALESCE(SUM(CASE WHEN status = 'completed' THEN total_cents END), 0),
    COUNT(CASE WHEN status = 'completed' THEN 1 END),
    COUNT(DISTINCT CASE
      WHEN status = 'completed' AND NOT EXISTS (
        SELECT 1 FROM orders o2
        WHERE o2.customer_id = orders.customer_id
          AND o2.created_at < date_trunc('day', p_date::timestamptz)
      ) THEN customer_id
    END),
    COALESCE(SUM(CASE WHEN status = 'refunded' THEN total_cents END), 0)
  FROM orders
  WHERE created_at >= p_date::timestamptz
    AND created_at < (p_date + 1)::timestamptz
  ON CONFLICT (date) DO UPDATE SET
    total_cents = EXCLUDED.total_cents,
    order_count = EXCLUDED.order_count,
    new_customers = EXCLUDED.new_customers,
    refunds_cents = EXCLUDED.refunds_cents;
END;
$$;
```

```ts
// Call from job
await supabase.rpc('aggregate_daily_revenue', { p_date: format(yesterday, 'yyyy-MM-dd') })
```

## Scheduling (GitHub Actions)

```yaml
# .github/workflows/analytics-jobs.yml
name: Daily Analytics

on:
  schedule:
    - cron: '0 2 * * *'   # 2am UTC daily
  workflow_dispatch:         # Manual trigger

jobs:
  aggregate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npx tsx scripts/aggregate-analytics.ts
        env:
          NEXT_PUBLIC_SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
```

## Reading from Summary Tables

```ts
// Dashboard — fast query, no aggregation at read time
async function getDashboardStats(days: number = 30) {
  const { data } = await supabase
    .from('daily_revenue_summary')
    .select('*')
    .gte('date', format(subDays(new Date(), days), 'yyyy-MM-dd'))
    .order('date', { ascending: true })

  return {
    totalRevenue: data?.reduce((sum, d) => sum + d.total_cents, 0) ?? 0,
    totalOrders: data?.reduce((sum, d) => sum + d.order_count, 0) ?? 0,
    newCustomers: data?.reduce((sum, d) => sum + d.new_customers, 0) ?? 0,
    chart: data ?? [],
  }
}
```

## Idempotency

Always use `upsert` with `onConflict`, not `insert`. If the job runs twice (retry, manual trigger), the second run overwrites with identical data rather than creating a duplicate row.
