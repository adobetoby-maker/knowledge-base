# Batch: Weekly User Engagement Report

## Overview
Engagement reports answer the question "are users getting value from the product?" at a cadence
appropriate for business decision-making. Weekly is the right cadence for most products — daily
is too noisy, monthly is too delayed to catch problems early. Automated generation ensures
stakeholders have consistent data without analyst intervention.

## Implementation

### Aggregate MAU/DAU Metrics
```sql
-- Daily Active Users (DAU): users with at least one session in the last 24h
WITH dau AS (
    SELECT
        DATE_TRUNC('day', session_start)::date AS date,
        COUNT(DISTINCT user_id) AS dau
    FROM user_sessions
    WHERE session_start >= NOW() - INTERVAL '30 days'
    GROUP BY 1
),
-- Monthly Active Users (MAU): users active in rolling 30-day window
mau AS (
    SELECT
        DATE_TRUNC('day', session_start)::date AS date,
        COUNT(DISTINCT user_id) OVER (
            ORDER BY DATE_TRUNC('day', session_start)::date
            RANGE BETWEEN INTERVAL '29 days' PRECEDING AND CURRENT ROW
        ) AS mau
    FROM user_sessions
    GROUP BY 1
)
SELECT dau.date, dau.dau, mau.mau,
    round(100.0 * dau.dau / mau.mau, 2) AS dau_mau_ratio  -- "stickiness"
FROM dau JOIN mau USING (date)
ORDER BY date DESC;
```

### Cohort Retention Curves
```sql
-- Week-over-week retention by signup cohort
WITH cohorts AS (
    SELECT
        user_id,
        DATE_TRUNC('week', created_at)::date AS cohort_week
    FROM users
),
activity AS (
    SELECT
        user_id,
        DATE_TRUNC('week', session_start)::date AS activity_week
    FROM user_sessions
    GROUP BY 1, 2
)
SELECT
    c.cohort_week,
    COUNT(DISTINCT c.user_id) AS cohort_size,
    COUNT(DISTINCT CASE WHEN a.activity_week = c.cohort_week + INTERVAL '1 week' THEN a.user_id END) AS week1_retained,
    COUNT(DISTINCT CASE WHEN a.activity_week = c.cohort_week + INTERVAL '4 weeks' THEN a.user_id END) AS week4_retained,
    COUNT(DISTINCT CASE WHEN a.activity_week = c.cohort_week + INTERVAL '8 weeks' THEN a.user_id END) AS week8_retained
FROM cohorts c
LEFT JOIN activity a USING (user_id)
WHERE c.cohort_week >= NOW() - INTERVAL '12 weeks'
GROUP BY c.cohort_week
ORDER BY c.cohort_week;
```

### Feature Adoption Rates
```sql
-- What % of users have used each key feature at least once
SELECT
    feature_name,
    COUNT(DISTINCT user_id) AS users_who_used,
    COUNT(DISTINCT user_id) * 100.0 / (SELECT COUNT(*) FROM users WHERE created_at > NOW() - INTERVAL '30 days') AS adoption_pct
FROM feature_events
WHERE occurred_at > NOW() - INTERVAL '30 days'
GROUP BY feature_name
ORDER BY adoption_pct DESC;
```

### Generate Weekly PDF/Email Digest
```ts
import PDFDocument from 'pdfkit';
import { db } from '../lib/db';

async function generateWeeklyEngagementReport() {
  const week_start = startOfWeek(new Date());
  const week_end = endOfWeek(new Date());

  const [dau_mau, cohorts, features] = await Promise.all([
    db.query(dauMauQuery),
    db.query(cohortRetentionQuery),
    db.query(featureAdoptionQuery),
  ]);

  // Format for email
  const report = {
    period: `${format(week_start, 'MMM d')} – ${format(week_end, 'MMM d, yyyy')}`,
    headline: {
      current_dau: dau_mau[0].dau,
      dau_change_pct: computeChangeFromPreviousWeek(dau_mau, 'dau'),
      current_mau: dau_mau[0].mau,
      stickiness: dau_mau[0].dau_mau_ratio,
    },
    retention: cohorts.slice(0, 8),
    features: features.slice(0, 10),
  };

  // Send to stakeholders
  const recipients = await db.from('report_subscribers').select('email').eq('report_type', 'weekly-engagement');
  await emailService.sendBatch(recipients, {
    subject: `Weekly Engagement Report: ${report.period}`,
    template: 'weekly-engagement',
    data: report,
  });

  // Archive in reporting DB
  await db.insert('weekly_reports', {
    report_type: 'engagement',
    week_start,
    data: report,
    generated_at: new Date(),
  });
}
```

### Store in Reporting DB for Trend Analysis
```sql
-- Reporting tables are append-only — never update, only insert
CREATE TABLE weekly_metrics (
    id          BIGSERIAL PRIMARY KEY,
    week_start  DATE NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value NUMERIC,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (week_start, metric_name)
);
```

## Key Rules
- DAU/MAU ratio (stickiness) is more informative than absolute DAU — it normalizes for growth
- Cohort retention must use signup week as the cohort definition, not first-active week — otherwise new-user activation is invisible
- Archive every report to a reporting table — trend analysis requires historical reports, not just current data
- Send to specific stakeholder groups (product team, exec team, investors) with appropriate levels of detail
- Compute week-over-week percentage changes, not just absolute values — changes are more actionable than snapshots
- Feature adoption = % of active users who used the feature; only count users who had the opportunity to use it
- Run report generation on Saturday night/Sunday morning — stakeholders read it Monday morning
