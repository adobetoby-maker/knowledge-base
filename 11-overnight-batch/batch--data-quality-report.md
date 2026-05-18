# Batch: Data Quality Monitoring Report

## Overview
Data quality degrades silently: a new intake form introduces a nullable field, an import job uses a different phone format, a bug starts creating orphaned records. Without automated monitoring, these issues accumulate for weeks before someone notices incorrect analytics or broken functionality. A nightly data quality report catches regressions before they compound and establishes baselines that make trends visible.

## Implementation

### Job Structure
```ts
// jobs/data-quality-report.ts — runs nightly at 2:00 AM

interface QualityCheck {
  name: string;
  table: string;
  column?: string;
  severity: 'critical' | 'warning' | 'info';
  currentValue: number;
  baseline: number;       // yesterday's value or rolling average
  threshold: number;      // alert if deviation exceeds this %
  status: 'pass' | 'warn' | 'fail';
}

interface QualityReport {
  runAt: Date;
  checks: QualityCheck[];
  overallScore: number;    // 0-100
  alerts: QualityCheck[];
}
```

### Null Rate Check
```sql
-- Compare null rate today vs baseline
WITH today AS (
  SELECT
    COUNT(*) AS total,
    COUNT(email) AS has_email,
    COUNT(phone) AS has_phone,
    COUNT(company) AS has_company
  FROM contacts
  WHERE created_at >= CURRENT_DATE - INTERVAL '1 day'
),
baseline AS (
  SELECT
    COUNT(*) AS total,
    COUNT(email) AS has_email,
    COUNT(phone) AS has_phone,
    COUNT(company) AS has_company
  FROM contacts
  WHERE created_at BETWEEN CURRENT_DATE - INTERVAL '8 days' AND CURRENT_DATE - INTERVAL '1 day'
)
SELECT
  'contacts.email' AS field,
  1 - (today.has_email::float / NULLIF(today.total, 0)) AS null_rate_today,
  1 - (baseline.has_email::float / NULLIF(baseline.total, 0)) AS null_rate_baseline
FROM today, baseline;
```

### Duplicate Detection
```sql
-- Exact email duplicates in last 24h intake
SELECT
  lower(trim(email)) AS normalized_email,
  count(*) AS duplicate_count,
  array_agg(id ORDER BY created_at) AS ids
FROM contacts
WHERE created_at >= CURRENT_DATE - INTERVAL '1 day'
  AND email IS NOT NULL
GROUP BY lower(trim(email))
HAVING count(*) > 1;

-- Cross-table: orders without matching users
SELECT count(*) AS orphaned_orders
FROM orders o
LEFT JOIN users u ON u.id = o.user_id
WHERE u.id IS NULL;
```

### Format Validation
```sql
-- Emails that don't match a basic regex
SELECT count(*) AS invalid_emails
FROM contacts
WHERE email IS NOT NULL
  AND email NOT SIMILAR TO '[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}';

-- Phones not in E.164 format
SELECT count(*) AS invalid_phones
FROM contacts
WHERE phone IS NOT NULL
  AND phone NOT SIMILAR TO '\+[1-9][0-9]{7,14}';
```

### Referential Integrity Check
```sql
-- Invoice line items pointing to deleted products
SELECT count(*) AS orphaned_line_items
FROM invoice_line_items li
LEFT JOIN products p ON p.id = li.product_id
WHERE p.id IS NULL AND p.deleted_at IS NULL;

-- Payments without matching orders
SELECT count(*) AS orphaned_payments
FROM payments pay
LEFT JOIN orders o ON o.id = pay.order_id
WHERE o.id IS NULL;
```

### Schema Drift Detection
```sql
-- Columns with >20% null rate that were previously non-nullable
-- (catches when an application started sending null for a field)
SELECT
  table_name,
  column_name,
  null_count,
  total_rows,
  round(100.0 * null_count / NULLIF(total_rows, 0), 2) AS null_pct
FROM (
  SELECT 'contacts' AS table_name, 'company' AS column_name,
    count(*) FILTER (WHERE company IS NULL) AS null_count,
    count(*) AS total_rows
  FROM contacts
  WHERE created_at >= CURRENT_DATE - INTERVAL '1 day'
) t
WHERE null_pct > 20;
```

### Orchestrator + Alerting
```ts
export async function runDataQualityReport() {
  const checks: QualityCheck[] = [];

  // Run all checks
  const nullRates = await checkNullRates();
  const duplicates = await checkDuplicates();
  const formatIssues = await checkFormats();
  const orphans = await checkReferentialIntegrity();

  checks.push(...nullRates, ...duplicates, ...formatIssues, ...orphans);

  // Calculate overall score
  const passed = checks.filter(c => c.status === 'pass').length;
  const score = Math.round((passed / checks.length) * 100);

  const alerts = checks.filter(c => c.status === 'fail' || c.status === 'warn');

  // Store report
  await db.qualityReports.create({
    runAt: new Date(),
    score,
    checkCount: checks.length,
    alertCount: alerts.length,
    details: checks,
  });

  // Alert on regressions
  if (alerts.some(a => a.severity === 'critical')) {
    await sendSlackAlert({
      channel: '#data-quality',
      message: `Data quality CRITICAL: ${alerts.filter(a => a.severity === 'critical').length} failures`,
      details: alerts.map(a => `${a.name}: ${a.currentValue} (baseline: ${a.baseline})`),
    });
  }

  return { score, alerts };
}
```

## Key Rules
- Establish baselines before alerting — you can't alert on regression without knowing what "normal" looks like.
- Null rate alerts should fire on rate change, not absolute null rate — some fields are legitimately optional.
- Alert on `critical` severity immediately via pager/Slack; aggregate `warning` severity into a daily digest.
- Store all quality reports in the DB — trending analysis requires historical data.
- Referential integrity checks are the most important — orphaned records indicate application-layer bugs that may cause silent data loss.
- Run the report before business hours (2 AM) so the team has results ready when they start work.
- A quality score below 70% should block data-dependent features until the root cause is fixed.
