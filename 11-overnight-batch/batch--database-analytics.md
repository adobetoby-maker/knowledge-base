# Batch: Analytics ETL Pipeline

## Overview
The operational database (OLTP) is optimized for transactional writes, not analytical queries.
Running reports directly against production degrades application performance and lacks the historical
aggregations analytics needs. The ETL pipeline extracts events from the operational database,
transforms them into analytical structures (sessions, funnels, cohorts), and loads them into a
warehouse optimized for analytical reads.

## Implementation

### Extract Events from Operational DB
```ts
// Extract only events since last successful ETL run (incremental)
async function extractEvents(lastRunAt: Date): Promise<RawEvent[]> {
  return operationalDb.query(sql`
    SELECT
        id,
        user_id,
        event_name,
        properties,        -- JSONB
        session_id,
        occurred_at,
        created_at
    FROM analytics_events
    WHERE created_at > ${lastRunAt}
    ORDER BY created_at ASC
    LIMIT 100000            -- batch cap — re-run if > 100k rows
  `);
}
```

### Transform: Sessionize Events
```ts
// Group events into sessions (30-minute inactivity timeout)
function sessionize(events: RawEvent[]): Session[] {
  const sessions: Session[] = [];
  const sessionMap = new Map<string, Session>();
  const SESSION_TIMEOUT_MS = 30 * 60 * 1000;

  for (const event of events.sort((a, b) => +a.occurred_at - +b.occurred_at)) {
    const lastSession = sessionMap.get(event.user_id);
    const timeSinceLast = lastSession
      ? +event.occurred_at - +lastSession.lastEventAt
      : Infinity;

    if (!lastSession || timeSinceLast > SESSION_TIMEOUT_MS) {
      // Start new session
      const session: Session = {
        sessionId: event.session_id ?? generateId(),
        userId: event.user_id,
        startedAt: event.occurred_at,
        lastEventAt: event.occurred_at,
        events: [event],
      };
      sessions.push(session);
      sessionMap.set(event.user_id, session);
    } else {
      lastSession.lastEventAt = event.occurred_at;
      lastSession.events.push(event);
    }
  }

  return sessions;
}
```

### Transform: Attribute Conversions
```ts
// Find the first touch that led to a conversion
function attributeConversions(sessions: Session[], conversions: ConversionEvent[]): AttributedConversion[] {
  return conversions.map(conversion => {
    // All sessions before this conversion for this user
    const priorSessions = sessions
      .filter(s => s.userId === conversion.userId && s.startedAt < conversion.occurredAt)
      .sort((a, b) => +b.startedAt - +a.startedAt);  // most recent first

    const firstTouch = priorSessions[priorSessions.length - 1];
    const lastTouch = priorSessions[0];

    return {
      ...conversion,
      firstTouchChannel: firstTouch?.channel ?? 'direct',
      lastTouchChannel: lastTouch?.channel ?? 'direct',
      touchCount: priorSessions.length,
      timeToConvertMs: +conversion.occurredAt - +(firstTouch?.startedAt ?? conversion.occurredAt),
    };
  });
}
```

### Load into Analytics DW
```ts
// BigQuery example
import { BigQuery } from '@google-cloud/bigquery';

const bq = new BigQuery();

async function loadToBigQuery(sessions: Session[], dataset: string) {
  const table = bq.dataset(dataset).table('sessions');

  await table.insert(
    sessions.map(s => ({
      session_id: s.sessionId,
      user_id: s.userId,
      started_at: s.startedAt.toISOString(),
      ended_at: s.lastEventAt.toISOString(),
      duration_seconds: (+s.lastEventAt - +s.startedAt) / 1000,
      event_count: s.events.length,
      // Flatten JSONB properties to typed columns for query performance
      first_page: s.events[0]?.properties?.page ?? null,
      conversion: s.events.some(e => e.event_name === 'purchase'),
    }))
  );
}
```

### Calculate Product Metrics + Refresh Dashboards
```ts
async function calculateMetrics() {
  // These run in the DW, not the operational DB
  await bq.query(`
    MERGE analytics.daily_metrics AS target
    USING (
      SELECT
          DATE(started_at) AS date,
          COUNT(DISTINCT user_id) AS dau,
          COUNT(*) AS total_sessions,
          AVG(duration_seconds) AS avg_session_duration,
          COUNTIF(conversion) / COUNT(*) AS conversion_rate
      FROM analytics.sessions
      WHERE DATE(started_at) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
      GROUP BY 1
    ) AS source ON target.date = source.date
    WHEN MATCHED THEN UPDATE SET ...
    WHEN NOT MATCHED THEN INSERT ...
  `);
}

// After metrics are computed, trigger dashboard refresh
async function refreshDashboards() {
  await fetch('https://api.metabase.com/api/dashboard/refresh', {
    method: 'POST',
    headers: { 'X-Metabase-Session': process.env.METABASE_TOKEN },
    body: JSON.stringify({ dashboard_id: process.env.METRICS_DASHBOARD_ID }),
  });
}
```

## Key Rules
- Never run analytical queries directly against the operational (OLTP) database — use read replicas at minimum
- Incremental extraction (by `created_at > last_run`) is mandatory — full re-extract grows linearly with data volume
- Store ETL run metadata (last_run_at, rows_processed, errors) in a jobs table for debugging and restart safety
- Sessionization timeout (30 min) must be consistent across all analysis — changing it invalidates historical comparisons
- Use `MERGE` (upsert) in the warehouse for daily aggregates — re-runs are idempotent and safe
- Test transformation logic with unit tests — a sessionization bug can corrupt months of retention data before being caught
- Dashboard refresh should happen AFTER metric calculation is confirmed complete, not scheduled independently
