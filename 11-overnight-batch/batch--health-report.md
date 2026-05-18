# Daily Application Health Summary Report

A daily health report is a forced review of yesterday's application state, delivered to the team before they start work. It transforms "we only find out something is wrong when users complain" into "we already knew about the spike in errors and it was resolved by 8am."

## What to Include

The report covers yesterday (midnight to midnight, team's local timezone). Include:

**Core metrics vs previous period:**
- New signups: count + % change vs same day last week
- Active users (DAU): count + % change
- Revenue / payments processed: total $ + count + % change
- API requests: total count + % change

"Previous period" is the same day last week, not yesterday-minus-one-day. Comparing Monday to Sunday is misleading due to weekly seasonality.

**Errors:**
- Total error count + % change
- Top 5 errors by count: error message, count, first seen, last seen, affected users
- New errors (not seen in prior 7 days): list all of them, even if low count. New errors are the highest signal.

**Uptime and performance:**
- Overall uptime percentage for the day
- p50/p95/p99 response time for key routes
- Any SLO breach windows (e.g., "p99 exceeded 2s for 14 minutes at 14:32 UTC")

**Infrastructure:**
- Unusual DB query counts or slow queries (if available)
- Background job queue depth at end of day
- Any 3rd-party dependency incidents (Stripe, Twilio, etc.) from status pages

## Building the Report

Query your metrics source in a single batch job scheduled at 1–2am (after the day ends but before the team starts). Sources:

- **Application metrics**: Prometheus/Datadog/PostHog query APIs
- **Error counts**: Sentry API or direct DB query on your error log table
- **Business metrics**: direct DB queries (signups, payments)
- **Status pages**: Atlassian Statuspage or betteruptime API for 3rd-party incidents

Compute deltas against last week's same day. Format numbers with context: "347 errors (+82% vs last Monday)" is more useful than "347 errors." Red/yellow/green thresholds make it scannable: green = within 10% of baseline, yellow = 10–50% deviation, red = >50% deviation or new errors.

## Delivery

**Slack** is the right channel for a daily health report — it's already where the team starts their day. Post to a dedicated `#app-health` or `#daily-metrics` channel so it doesn't get lost in general channels. Include color-coded status emoji (🟢🟡🔴) at the top so the health state is visible without reading the full report.

**Email** as a secondary delivery for stakeholders who don't use Slack daily. Attach the Grafana/Datadog dashboard link so recipients can drill in.

Format: brief. The goal is 60-second scannability. If a section needs more than 3–4 lines, link out to the full dashboard. The report is a trigger for investigation, not the investigation itself.

## Alerting vs Reporting

The health report is not a replacement for real-time alerting. Real-time alerts fire immediately when thresholds are crossed. The health report is a summary of what happened and how the day looked in aggregate.

Do not add "alert on this in the health report" for things that need immediate attention. Add them to your real-time alerting instead. The health report surfaces patterns and trends; alerts surface incidents.

## Key Rules

- Cover midnight-to-midnight in team's local timezone; compare to same day last week, not prior day
- Always include: new signups, revenue, error count, top-5 errors, new errors, uptime, p99 latency
- Highlight new errors explicitly — new is more important than high-count known errors
- Red/yellow/green status for at-a-glance readability; 60-second scan target
- Deliver to Slack + email; include dashboard link for drill-down
- Run at 1–2am after the day ends; deliver before team start time
- Health report is for patterns and trends; real-time alerting handles incidents
