# Principle: Rollout Readiness

## Overview
Features that ship without monitoring, rollback plans, or stakeholder awareness create predictable crises. The feature works in staging, gets deployed to production, and then reality diverges from staging in ways nobody anticipated. Rollout readiness is a checklist that must be satisfied before a feature reaches users — not as bureaucracy, but as the minimum conditions for a deployment that does not require firefighting.

## The Readiness Checklist

Before any feature goes live, verify:

### 1. Feature Flag Configured
- Feature is gated behind a flag at 0% or targeting only internal users
- Flag can be disabled without a code deploy
- The flag name and service are documented for the oncall team

### 2. Monitoring and Alerting
- Dashboard panel showing the key metric for this feature exists
- Alert fires if error rate for new code path exceeds baseline
- Alert fires if latency P99 exceeds acceptable threshold
- Alert fires if business metric (conversion, completion) drops below baseline

```typescript
// Every new feature logs its key events
logger.info("checkout.new_flow.completed", { userId, durationMs, success });
logger.error("checkout.new_flow.failed", { userId, reason });

// Alerting: if failed / (completed + failed) > 2% → fire alert
```

### 3. Rollback Documented
- Written step-by-step: "disable flag at X, then verify metric Y recovers"
- Rollback can be performed by anyone with oncall access, not just the feature author
- Rollback time estimate: should be under 5 minutes for feature flags, under 15 minutes for data migrations

### 4. Load Tested (When Performance-Sensitive)
- New endpoints that are expected to receive high traffic have been load tested in a staging environment
- P99 latency under expected peak load is within acceptable range
- Database query plans reviewed for new queries that will run at high frequency

### 5. Stakeholders Notified
- Product team knows the feature is shipping and when
- Customer-facing changes communicated to support team before users notice
- Marketing/sales informed if the feature affects messaging or sales pitches

### 6. Support Team Briefed
- Common user questions about the new feature documented
- Known edge cases that users might hit documented
- Escalation path defined for issues that require engineering

### 7. Data Migration Completed or Planned
- Any data migration has been rehearsed in staging
- Migration is backward-compatible (old code can read new data format)
- Rollback data migration plan exists

## Rollout Sequence for High-Stakes Features

```
Day -3: Internal testing (employees, beta users)
Day -2: 1% external rollout — monitor error rates
Day -1: 10% rollout — monitor business metrics
Day 0: 50% rollout — sustained monitoring 4+ hours
Day +1: 100% rollout — close rollout
Day +7: Remove old code path, clean up flag
```

Each step requires explicit sign-off that the monitored metrics are healthy.

## The "Nothing Is On Fire" Problem

A feature can pass all technical checks and still fail because:
- The UX is confusing and users abandon the flow (monitor conversion, not just errors)
- A partner API has a quota that is hit at production scale
- The feature is technically working but business logic is wrong

This is why synthetic monitoring and business metric dashboards are part of readiness, not just error rate monitoring.

## Key Rules
- No feature ships to users without a monitoring dashboard for its key metric
- Every feature has a rollback plan executable by oncall in < 5 minutes
- Support team is briefed before any user-visible change
- Load test any endpoint expected to handle > 10 req/s that did not exist before
- Feature flags are the rollback mechanism — design features to be flag-gated
- Readiness checklist is completed by the feature author, reviewed by team lead
- "We'll add monitoring after launch" = you will be paged at 2am before you add it
