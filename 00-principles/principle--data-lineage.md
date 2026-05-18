# Principle: Data Lineage

## Overview
When a dashboard shows the wrong revenue number, or a GDPR deletion request arrives, or an audit finds inconsistent records, the first question is: "where did this data come from, and what happened to it?" Without data lineage — a traceable record of data origin, transformation, and movement — answering that question requires forensic archaeology through application logs and git history. Lineage is the provenance record that makes data trustworthy and auditable.

## What Data Lineage Tracks

For every piece of data in your system, lineage answers:
- **Origin:** Where did this data come from? (user input, third-party API, data import, internal calculation)
- **Time:** When was it ingested or created?
- **Transformation:** What happened to it between source and current state?
- **Ownership:** Which system, user, or process wrote it?

## Event Log as Lineage Record

The most practical lineage implementation is an append-only event log:

```sql
CREATE TABLE data_events (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  entity_type TEXT NOT NULL,          -- 'order', 'customer', 'invoice'
  entity_id   UUID NOT NULL,
  event_type  TEXT NOT NULL,          -- 'created', 'updated', 'imported', 'calculated'
  source      TEXT NOT NULL,          -- 'user_input', 'stripe_webhook', 'csv_import', 'cron_job'
  actor_id    TEXT,                   -- user_id or service name
  payload     JSONB NOT NULL,         -- the data at this point in time
  prior_hash  TEXT                    -- hash of previous event for tamper detection
);
```

This gives you a complete audit trail: for any entity, `SELECT * FROM data_events WHERE entity_id = $1 ORDER BY occurred_at` shows every state transition and its origin.

## Lineage for ETL and Analytics Pipelines

In data pipelines, lineage tracks transformation steps:

```typescript
interface PipelineStep {
  stepName: string;
  inputTables: string[];
  outputTable: string;
  transformationLogic: string;  // SQL or description
  ranAt: Date;
  rowsRead: number;
  rowsWritten: number;
  checksum: string;  // hash of output to detect silent corruption
}
```

This answers: "The revenue figure in the dashboard comes from `orders` → `daily_revenue_mv` → `finance_summary`, last updated 3 hours ago."

## GDPR and Compliance Use Cases

GDPR right-to-erasure requires knowing everywhere a user's data exists:
```sql
-- Find all data events for a specific user
SELECT entity_type, entity_id, event_type, source, occurred_at
FROM data_events
WHERE actor_id = 'user_abc123'
   OR payload @> '{"email": "user@example.com"}'
ORDER BY occurred_at;
```

Without lineage: responding to a GDPR deletion request takes weeks and may be incomplete.
With lineage: complete within hours.

## Debugging Bad Data

When a customer reports "my order total is wrong":
```sql
SELECT event_type, source, actor_id, payload, occurred_at
FROM data_events
WHERE entity_type = 'order' AND entity_id = $1
ORDER BY occurred_at;
```

Output: order was created via API, price was updated by admin user X at 2pm, discount was applied by cron job at 3pm. The 3pm cron job used incorrect tax rate. Root cause found in minutes.

## Lineage vs Logging

- **Logs** record operational events (requests, errors, performance). They're for debugging system behavior.
- **Lineage** records data provenance (who touched this data, from where, when). It's for understanding data correctness.

Both are needed. Logs are ephemeral (often purged after 30–90 days). Lineage is permanent (or as long as the data exists).

## Implementation Pragmatics

Lightweight approach: add `created_by`, `updated_by`, `source` columns to key tables plus a changes audit table.

Heavy approach: event sourcing (store only events, derive current state from event replay).

Start with the lightweight approach for most applications; adopt event sourcing only when replay-derived state is a product requirement.

## Key Rules
- Track source (where did this data come from?), actor (who/what created it?), and time for every significant data write
- The event log is append-only — never update or delete lineage records
- GDPR compliance requires lineage to locate all data for a specific user across all systems
- "Bad data" bugs are 10x faster to diagnose with lineage than with application logs alone
- Pipeline lineage must include checksums to detect silent data corruption between steps
- Schema changes to lineage tables must be backward-compatible — they're permanent records
