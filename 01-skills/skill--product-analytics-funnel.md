# Skill: Product Analytics Funnel

## Overview
A funnel converts raw event data into conversion rates at each step, exposing exactly where users drop off. Without a shared session ID stitching events together, drop-off calculations are meaningless. Without segmenting by acquisition channel, you can't act on the findings — because "fix the funnel" is not a strategy, but "fix the funnel for paid search users" is.

## Implementation / Key Points

### Define Conversion Steps First
Before writing any tracking code, agree on the funnel definition:
```
1. Landing page view        → event: page_viewed { page: '/signup' }
2. Email entered            → event: signup_email_entered
3. Account created          → event: account_created
4. First feature used       → event: first_action_completed { action: 'project_created' }
5. Paid conversion          → event: subscription_started { plan, mrr }
```
Document this in a tracking plan (spreadsheet or analytics tool) before implementation.

### Event Tracking Pattern
```ts
// Every funnel event shares session_id and user_id (or anonymous_id)
analytics.track('signup_email_entered', {
  session_id: getSessionId(),       // stable for the session
  anonymous_id: getAnonymousId(),   // stable pre-login
  user_id: user?.id ?? null,        // set post-login
  acquisition_channel: getChannel(),// utm_source or direct
  timestamp: new Date().toISOString(),
});
```
The `session_id` is the glue. Without it, PostHog/Mixpanel cannot connect step 2 to step 3.

### Calculating Drop-Off
```sql
-- Funnel SQL (BigQuery / Redshift pattern)
WITH funnel AS (
  SELECT
    session_id,
    MAX(CASE WHEN event = 'page_viewed' AND page = '/signup' THEN 1 END) AS step1,
    MAX(CASE WHEN event = 'signup_email_entered' THEN 1 END) AS step2,
    MAX(CASE WHEN event = 'account_created' THEN 1 END) AS step3
  FROM events
  WHERE DATE(timestamp) >= CURRENT_DATE - 30
  GROUP BY session_id
)
SELECT
  COUNT(*) FILTER (WHERE step1 = 1) AS reached_step1,
  COUNT(*) FILTER (WHERE step2 = 1) AS reached_step2,
  COUNT(*) FILTER (WHERE step3 = 1) AS reached_step3,
  ROUND(100.0 * COUNT(*) FILTER (WHERE step2 = 1) / NULLIF(COUNT(*) FILTER (WHERE step1 = 1), 0), 1) AS step1_to_step2_pct
FROM funnel;
```

### Cohort Analysis
Group users by the week they first saw step 1, then track their conversion rates separately. Users who arrived via a blog post last month may have different conversion than users from a paid ad today. Mixing cohorts hides which acquisition improvements worked.

### Segmenting by Acquisition Channel
```ts
function getChannel(): string {
  const params = new URLSearchParams(window.location.search);
  const utmSource = params.get('utm_source');
  if (utmSource) return utmSource;
  const referrer = document.referrer;
  if (!referrer) return 'direct';
  if (referrer.includes('google.com')) return 'organic_search';
  return 'referral';
}
```
Store channel on the first anonymous event; carry it forward on all subsequent events for the same anonymous_id.

### Weekly Funnel Review Cadence
- Pull funnel data every Monday morning (automated report).
- Track each step's rate week-over-week.
- Alert if any step drops > 5% from the prior 4-week average.
- Pick one bottleneck step per sprint to investigate.

## Key Rules
- Define the funnel before writing tracking code — retrofitting tracking is expensive.
- Every event must carry `session_id` and `anonymous_id` (pre-auth) or `user_id` (post-auth).
- Track acquisition channel on the very first touch; never overwrite it.
- Analyze cohorts separately — mixing signup months hides causality.
- Alert on statistical drops, not just visual eyeballing.
- Funnel windows matter: measure conversion within a specific time window (e.g., 7 days from step 1) for consistency.
