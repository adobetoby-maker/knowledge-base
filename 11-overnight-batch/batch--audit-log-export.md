# Batch: Audit Log Archival

## Overview
Audit logs must be retained for compliance (SOC 2, HIPAA, GDPR require 1-7 years depending on
jurisdiction and data type) but hot storage of multi-year audit logs is expensive and slows queries.
Archival moves old logs to cold storage (S3 Glacier, GCS Nearline) while maintaining a searchable
index for compliance queries — balancing cost, access speed, and legal requirements.

## Implementation

### Export Audit Events to Cold Storage
```ts
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

const s3 = new S3Client({ region: process.env.AWS_REGION });

async function archiveAuditLogs(beforeDate: Date) {
  const BATCH_SIZE = 10_000;
  let offset = 0;
  let totalArchived = 0;

  while (true) {
    const batch = await db.query(sql`
      SELECT * FROM audit_logs
      WHERE created_at < ${beforeDate}
        AND archived = false
      ORDER BY created_at ASC
      LIMIT ${BATCH_SIZE} OFFSET ${offset}
    `);

    if (batch.length === 0) break;

    // Group by month for efficient archive file organization
    const byMonth = groupBy(batch, row => format(row.created_at, 'yyyy-MM'));

    for (const [month, records] of Object.entries(byMonth)) {
      const key = `audit-logs/${month}/batch-${Date.now()}.jsonl`;
      const body = records.map(r => JSON.stringify(r)).join('\n');

      await s3.send(new PutObjectCommand({
        Bucket: process.env.AUDIT_ARCHIVE_BUCKET,
        Key: key,
        Body: body,
        StorageClass: 'GLACIER_IR',   // Glacier Instant Retrieval — ~12hr vs Glacier's ~4hr
        ContentType: 'application/x-ndjson',
        Metadata: {
          'record-count': String(records.length),
          'date-range-start': records[0].created_at.toISOString(),
          'date-range-end': records[records.length - 1].created_at.toISOString(),
        },
      }));

      // Update archive index in DB
      await db.insert('audit_archive_index', {
        month,
        s3_key: key,
        record_count: records.length,
        date_range_start: records[0].created_at,
        date_range_end: records[records.length - 1].created_at,
        archived_at: new Date(),
      });
    }

    // Mark as archived in source table
    await db.update('audit_logs')
      .set({ archived: true })
      .whereIn('id', batch.map(r => r.id));

    totalArchived += batch.length;
    offset += BATCH_SIZE;
  }

  return { totalArchived };
}
```

### Searchable Index of Archived Logs
```sql
-- The index stays in hot storage (DB); the data moves to cold storage
CREATE TABLE audit_archive_index (
    id           BIGSERIAL PRIMARY KEY,
    month        CHAR(7) NOT NULL,     -- '2023-06'
    s3_key       TEXT NOT NULL,
    record_count INT NOT NULL,
    date_range_start TIMESTAMPTZ NOT NULL,
    date_range_end   TIMESTAMPTZ NOT NULL,
    archived_at  TIMESTAMPTZ NOT NULL,

    -- Searchable metadata extracted from audit events
    user_ids     TEXT[],               -- users who appear in this batch
    event_types  TEXT[],               -- distinct event types in this batch
    resource_types TEXT[]              -- distinct resource types
);

CREATE INDEX idx_archive_index_month ON audit_archive_index (month);
CREATE INDEX idx_archive_index_user_ids ON audit_archive_index USING GIN (user_ids);
CREATE INDEX idx_archive_index_event_types ON audit_archive_index USING GIN (event_types);
```

### Compliance Report Generation
```ts
// "Show all actions by user X between dates A and B"
async function generateComplianceReport(userId: string, from: Date, to: Date) {
  // 1. Check hot storage (last 90 days)
  const hotLogs = await db.query(sql`
    SELECT * FROM audit_logs
    WHERE user_id = ${userId}
      AND created_at BETWEEN ${from} AND ${to}
      AND archived = false
    ORDER BY created_at ASC
  `);

  // 2. Find cold storage archives that may contain data for this user
  const archiveBatches = await db.query(sql`
    SELECT s3_key FROM audit_archive_index
    WHERE ${userId} = ANY(user_ids)
      AND date_range_start <= ${to}
      AND date_range_end >= ${from}
  `);

  // 3. Download and filter cold storage batches
  const coldLogs: AuditLog[] = [];
  for (const batch of archiveBatches) {
    const data = await downloadFromS3(batch.s3_key);  // initiates Glacier retrieval if needed
    const records = data
      .split('\n')
      .map(line => JSON.parse(line))
      .filter(r => r.user_id === userId && r.created_at >= from && r.created_at <= to);
    coldLogs.push(...records);
  }

  // 4. Merge and sort
  const allLogs = [...hotLogs, ...coldLogs].sort((a, b) => +a.created_at - +b.created_at);

  return generatePDFReport(allLogs, { userId, from, to });
}
```

### Anomalous Access Detection
```sql
-- Flag unusual access patterns (bulk reads, off-hours access, new IP ranges)
SELECT
    user_id,
    DATE_TRUNC('hour', created_at) AS hour,
    COUNT(*) AS action_count,
    COUNT(DISTINCT resource_id) AS distinct_resources,
    array_agg(DISTINCT action) AS actions
FROM audit_logs
WHERE created_at > NOW() - INTERVAL '1 day'
GROUP BY user_id, hour
HAVING
    COUNT(*) > 500                                    -- bulk operation threshold
    OR COUNT(DISTINCT resource_id) > 100              -- accessing many resources
    OR (EXTRACT(HOUR FROM created_at) NOT BETWEEN 6 AND 22)  -- off-hours (adjust for timezone)
ORDER BY action_count DESC;
```

## Key Rules
- Archive logs older than 90 days to cold storage; retain the index in hot storage — index queries cost milliseconds, data retrieval costs hours
- Use NDJSON (newline-delimited JSON) for archive files — it is streamable and queryable with tools like jq
- Glacier Instant Retrieval over Glacier Standard for compliance use cases — 12ms retrieval vs hours
- The archive index must include searchable metadata (user IDs, event types) to avoid retrieving entire archive files for targeted queries
- Retention period is legally defined: SOC 2 = 1 year minimum, HIPAA = 6 years, GDPR = "no longer than necessary" (varies by purpose)
- Anomaly detection runs on hot logs only — cold storage is for compliance retrieval, not real-time monitoring
- Archive batches must be immutable after write — set S3 Object Lock for compliance (prevents deletion or overwrite)
