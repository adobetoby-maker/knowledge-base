# Batch: Nightly Slow Query Detection

## What This Covers

Automated nightly analysis of slow database queries: enabling `pg_stat_statements`, querying the top N slowest queries, running EXPLAIN ANALYZE on regressions, alerting on new bottlenecks, and auto-creating issues in Linear or Jira.

## Why Run This Nightly

Slow queries degrade silently. A query that was fast in development with 100 rows becomes a 4-second full table scan at 500,000 rows. Without proactive detection, you find out when a customer complains about a slow page at 2pm on a Tuesday.

The pattern: collect query stats daily, compare against baseline, alert on regressions before users notice.

## Enabling `pg_stat_statements`

This extension must be enabled before stats accumulate. It tracks execution count, total/mean/max time, and rows per query.

```sql
-- Enable the extension (requires superuser, done once)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Verify it's tracking
SELECT query, calls, mean_exec_time, max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 5;
```

The `pg_stat_statements.max` parameter (default 5000) controls how many distinct queries are tracked. If your app has more than 5000 distinct query shapes, increase it in `postgresql.conf`.

## Nightly Analysis Script

```ts
// scripts/analyze-slow-queries.ts
import { db } from '../lib/db'
import { linearClient } from '../lib/linear'
import { sendSlackAlert } from '../lib/slack'

const SLOW_QUERY_THRESHOLD_MS = 500   // queries averaging > 500ms are flagged
const REGRESSION_THRESHOLD = 1.5      // 50% slower than yesterday triggers alert
const TOP_N = 20

async function analyzeSlowQueries() {
  const today = new Date().toISOString().split('T')[0]
  
  // 1. Get top N slowest queries by mean execution time
  const slowQueries = await db.query(`
    SELECT
      queryid,
      left(query, 200) AS query_preview,
      calls,
      round(mean_exec_time::numeric, 2) AS mean_ms,
      round(max_exec_time::numeric, 2) AS max_ms,
      round(total_exec_time::numeric, 2) AS total_ms,
      rows
    FROM pg_stat_statements
    WHERE mean_exec_time > $1
      AND calls > 10  -- ignore one-off queries
    ORDER BY mean_exec_time DESC
    LIMIT $2
  `, [SLOW_QUERY_THRESHOLD_MS, TOP_N])
  
  // 2. Store today's snapshot for tomorrow's regression detection
  await db.query(`
    INSERT INTO query_stats_snapshots (date, queryid, mean_ms, calls)
    SELECT $1, queryid, mean_exec_time, calls FROM pg_stat_statements
    WHERE mean_exec_time > $2
    ON CONFLICT (date, queryid) DO UPDATE SET mean_ms = EXCLUDED.mean_ms
  `, [today, SLOW_QUERY_THRESHOLD_MS])
  
  // 3. Detect regressions vs yesterday
  const regressions = await db.query(`
    SELECT
      t.queryid,
      t.mean_ms AS today_ms,
      y.mean_ms AS yesterday_ms,
      round((t.mean_ms / y.mean_ms)::numeric, 2) AS ratio
    FROM query_stats_snapshots t
    JOIN query_stats_snapshots y ON t.queryid = y.queryid
    WHERE t.date = $1 AND y.date = $1::date - 1
      AND t.mean_ms / y.mean_ms > $2
  `, [today, REGRESSION_THRESHOLD])
  
  return { slowQueries: slowQueries.rows, regressions: regressions.rows }
}
```

## Running EXPLAIN ANALYZE on Flagged Queries

For each regressed query, run EXPLAIN ANALYZE to capture the query plan:

```ts
async function explainQuery(queryText: string): Promise<string> {
  // Strip bind parameter placeholders for EXPLAIN
  const normalized = queryText.replace(/\$\d+/g, 'NULL')
  
  try {
    const result = await db.query(`EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) ${normalized}`)
    return result.rows.map((r: any) => r['QUERY PLAN']).join('\n')
  } catch {
    // Query may not be safe to re-run (e.g., mutations); return the query text only
    return `[Could not run EXPLAIN ANALYZE — mutation or unsafe query]\n${queryText}`
  }
}
```

Only run EXPLAIN ANALYZE on SELECT queries. For INSERT/UPDATE/DELETE, log the query shape and recommend manual investigation.

## Alerting and Issue Creation

```ts
async function reportFindings(slowQueries: QueryStat[], regressions: Regression[]) {
  if (regressions.length === 0 && slowQueries.length === 0) return
  
  const summary = [
    `*Slow Query Report — ${new Date().toDateString()}*`,
    `Queries above ${SLOW_QUERY_THRESHOLD_MS}ms: ${slowQueries.length}`,
    `Regressions (>50% slower than yesterday): ${regressions.length}`,
  ].join('\n')
  
  // Post to Slack #engineering channel
  await sendSlackAlert({ channel: '#db-alerts', text: summary })
  
  // Auto-create Linear issue for each regression
  for (const regression of regressions) {
    const plan = await explainQuery(regression.query_preview)
    
    await linearClient.createIssue({
      teamId: process.env.LINEAR_TEAM_ID!,
      title: `DB regression: query ${regression.queryid} is ${regression.ratio}x slower`,
      description: [
        `**Query (preview):** \`${regression.query_preview}\``,
        `**Yesterday:** ${regression.yesterday_ms}ms avg`,
        `**Today:** ${regression.today_ms}ms avg`,
        `\n**EXPLAIN ANALYZE:**\n\`\`\`\n${plan}\n\`\`\``,
      ].join('\n'),
      priority: regression.ratio > 3 ? 1 : 2,  // Urgent if 3x slower
      labelIds: [process.env.LINEAR_PERFORMANCE_LABEL_ID!],
    })
  }
}
```

## Supporting Table

```sql
CREATE TABLE query_stats_snapshots (
  date      DATE NOT NULL,
  queryid   BIGINT NOT NULL,
  mean_ms   DOUBLE PRECISION NOT NULL,
  calls     BIGINT NOT NULL,
  PRIMARY KEY (date, queryid)
);

-- Auto-prune: keep 90 days of snapshots
CREATE INDEX ON query_stats_snapshots (date);
```

Delete rows older than 90 days as part of the same nightly job to keep the table small.

## Key Rules

- Enable `pg_stat_statements` before you need it — enabling it after a slowdown means you have no baseline
- Filter to queries with `calls > 10` to avoid alerting on one-off admin scripts
- Snapshot today's stats before resetting — `pg_stat_reset()` wipes the data, never run it in this script
- Run EXPLAIN ANALYZE only on SELECT queries; skip mutations to avoid side effects
- Compare against yesterday's snapshot to detect regressions, not absolute thresholds alone
- Auto-create issues for regressions so they don't get lost in Slack
- Retain 90 days of snapshots for trend analysis; prune older rows nightly
