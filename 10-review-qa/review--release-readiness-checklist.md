# Review: Release Readiness Checklist

## Overview
A release readiness checklist exists to prevent the class of incidents caused by deploying code
that is technically functional but operationally unprepared — missing migrations, unset alerts,
no rollback plan, stakeholders surprised by a change. The checklist is the last line of defense
before code reaches users.

## Implementation

### Migrations Reviewed and Tested
```bash
# Verify migrations are backwards compatible BEFORE deploying code
# Old code must work with new schema (zero-downtime deploys require this)

# Safe migration patterns:
# 1. Add column as nullable (old code ignores it)
ALTER TABLE users ADD COLUMN preferences JSONB;  -- nullable, old code unaffected

# 2. Add index concurrently (doesn't lock table)
CREATE INDEX CONCURRENTLY idx_users_email ON users (email);

# Unsafe patterns (require maintenance window):
# - NOT NULL column without default (old code can't insert)
# - Renaming column (old code uses old name)
# - Dropping column (old code reads it)

# Verify on staging:
npx prisma migrate status   # no pending migrations
# Run the migration, check rows, verify app still works
```

### Feature Flags Configured
```
Checklist:
✓ New features behind a feature flag for gradual rollout?
✓ Flag configured correctly in all environments?
✓ Default value (off/on) is the correct safe default?
✓ Flag name and behavior documented in the flag manager?
✓ Rollout plan documented (10% → 50% → 100% over what timeframe)?

Example:
  Flag: NEW_INVOICE_FLOW
  Staging: enabled for all
  Production: enabled for 0% — will ramp to 10% after 24h observation
```

### Monitoring Alerts Set
```
Minimum alerting for any new endpoint or feature:
✓ Error rate alert (e.g., > 1% 5xx in 5 minutes → PagerDuty/Slack)
✓ Latency alert (e.g., p99 > 2s over 5 minutes)
✓ Critical business metric alert (payment failures, auth failures)

# Datadog example:
monitors:
  - name: "New checkout flow error rate"
    query: "sum(last_5m):sum:trace.http.request.errors{service:checkout,resource_name:POST_/checkout} / sum:trace.http.request.hits{service:checkout,resource_name:POST_/checkout} > 0.01"
    alert_threshold: 0.01   # 1% error rate
```

### Rollback Plan Documented
```
For every deployment, document in the release ticket:
1. How to detect the issue (what metric/alert would trigger rollback?)
2. How to rollback:
   - Application: git revert + deploy (takes X minutes)
   - Feature flag: disable flag (takes < 1 minute, no deploy)
   - Database: migration rollback command + any data implications

Example:
  Rollback trigger: Error rate > 2% on /api/checkout for 3 minutes
  Rollback method: 
    1. Set CHECKOUT_V2_ENABLED flag to false (immediate)
    2. If that doesn't fix it: `git revert HEAD~1 && git push` + Vercel auto-deploy (~3 min)
  Data risk: None — new checkout flow writes to same tables
```

### Load Testing (Traffic-Sensitive Changes)
```bash
# Use k6, Locust, or Artillery for load testing before high-traffic deploys

# k6 example for a new endpoint
import http from 'k6/http';
export const options = {
  stages: [
    { duration: '2m', target: 50 },    // ramp up to 50 users
    { duration: '5m', target: 50 },    // hold
    { duration: '2m', target: 0 },     // ramp down
  ],
  thresholds: {
    http_req_duration: ['p95<500'],     // 95% of requests under 500ms
    http_req_failed: ['rate<0.01'],     // < 1% failure rate
  },
};
```
Load test on staging with production-like data volume before deploying to production.

### Stakeholder Sign-Off
```
Who needs to know before this deploys?
✓ Product manager (for user-facing features)
✓ Customer support (for changes to behavior they help users with)
✓ Legal/compliance (for PII handling changes, data retention changes)
✓ Marketing (if the feature is being announced simultaneously)
✓ Data/analytics (if event schema or metrics change)

Document sign-off in the release ticket before deploying.
```

### Communications Plan (User-Facing Changes)
```
✓ In-app notification or announcement drafted?
✓ Help documentation updated?
✓ Customer support team briefed on what changed?
✓ Release notes written?
✓ Social/email announcement scheduled (if appropriate)?

For degradations/breaking changes (even to internal tools):
✓ Email sent to affected users in advance
✓ Changelog entry written
✓ Deprecation timeline communicated (if replacing a feature)
```

## Key Rules
- Backwards-compatible migrations deploy before code; destructive migrations deploy only after old code is fully gone
- Feature flags are not optional for major user-facing changes — they are the rollback mechanism
- Every release must have a documented rollback procedure before the deploy starts, not after an incident
- Load test any endpoint that will receive more traffic than it currently handles in production
- "Stakeholder sign-off" means written confirmation in the ticket, not a verbal assumption of approval
- Communications must go out before the deploy for breaking changes, not after users discover the change
- Monitoring alerts must be configured before the feature is enabled in production — not after
