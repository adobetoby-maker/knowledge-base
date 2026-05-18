# Review: Monitoring and Alerting Review

## Overview
Monitoring that doesn't lead to action is just noise. The most common monitoring failure isn't missing data — it's alerts that fire constantly (alert fatigue) or alerts that don't fire when something is wrong (blind spots). A well-designed monitoring system means you learn about problems before your users do and can act with a clear runbook.

## Implementation / Key Points

### The Four Golden Signals (Google SRE)
Every service should have visibility into all four:

| Signal | What to Measure | Alert On |
|---|---|---|
| **Latency** | p95, p99 response time | p95 > SLA threshold |
| **Traffic** | Requests per second | Sudden drop (service down?) |
| **Errors** | Error rate (4xx/5xx) | Error rate > 1% |
| **Saturation** | CPU, memory, connection pool % | > 80% sustained |

A service missing any of these four has a blind spot.

### Alert Severity Tiers
```yaml
# Paging alerts — require human action NOW
- name: error-rate-high
  condition: error_rate > 0.05  # 5%
  severity: page
  runbook: https://docs.internal/runbooks/error-rate
  
# Slack-only — informational, no immediate action
- name: error-rate-elevated  
  condition: error_rate > 0.01  # 1%
  severity: slack
```

**Paging alert = someone wakes up at 3am.** This must be justified. If a paging alert fires and the on-call person determines no action was needed, the alert threshold is wrong.

### Alert Calibration
- **Too sensitive**: Alert fires on brief spikes that self-resolve. Engineers learn to ignore it (alert fatigue).
- **Too coarse**: Alert fires only when the outage is already severe.

Use **evaluation windows** and **for clauses** (Prometheus/Grafana terminology):
```yaml
# Bad: fires on any single spike
alert: HighLatency
expr: p95_latency > 500

# Good: fires only if sustained for 5 minutes
alert: HighLatency
expr: p95_latency > 500
for: 5m
```

### Every SLA Has an Alert
```
SLA: "99.9% of requests complete in < 500ms"

Required:
- Alert when p95 > 500ms for > 5 minutes
- Dashboard showing p95 over 30 days
- Monthly SLA report
```
If an SLA exists without a corresponding alert, it's an unmonitored promise.

### Every Alert Has a Runbook
```yaml
alert: DatabaseConnectionPoolExhausted
expr: db_pool_available_connections < 5
for: 2m
annotations:
  summary: "DB connection pool nearly exhausted"
  runbook: "https://docs.internal/runbooks/db-pool"
```
An alert without a runbook forces the on-call engineer to start from scratch at 3am. The runbook should explain: what caused this, how to diagnose, how to mitigate.

### On-Call Rotation Exists for Paging Alerts
Any alert that can page must have a rotation:
- Who is primary on-call?
- Who is the secondary escalation?
- What's the rotation schedule?

An alert that pages a single person 24/7 is a burnout engine.

### Dashboard Structure
```
Level 1: Service Overview
- Error rate (all endpoints)
- p95 latency (all endpoints)  
- RPS
- Saturation (CPU, memory)

Level 2: Per-Endpoint Breakdown
- Latency heatmap by endpoint
- Error rate by endpoint
- Top error messages

Level 3: Dependencies
- Database query latency
- External API latency
- Queue depth
```

### Monitoring Review Checklist
- [ ] All four golden signals tracked per service
- [ ] Every paging alert has a runbook link in the alert body
- [ ] Alert thresholds tested against historical data (not set arbitrarily)
- [ ] `for` clauses on all alerts to avoid false positives from brief spikes
- [ ] On-call rotation exists for paging alerts
- [ ] No alert has fired and been ignored > 3 times without being fixed or removed
- [ ] Traffic drop alert exists (catches full outage that other alerts might miss)
- [ ] SLA targets have corresponding alerts

## Key Rules
- Paging alerts must require immediate human action — if not, move to Slack-only
- Alert fatigue is a monitoring failure: too many non-actionable alerts makes engineers ignore real ones
- Every alert needs a runbook; without it you're paging someone to figure it out cold
- Traffic drop (sudden RPS decrease) is often the first signal of a full outage — add this alert
- Saturation at > 80% sustained is a leading indicator of failure, not a lagging one
- Monitor the four golden signals at minimum: latency, traffic, errors, saturation
- Review alert thresholds quarterly — what was appropriate at launch may be wrong after growth
