# Skill: Error Tracking Triage Workflow

## Overview
An error tracking system is only useful if the team actually acts on it. Without a defined triage workflow, alerts get ignored, the same errors appear repeatedly, and the dashboard becomes noise. The workflow: fingerprint for grouping, assign ownership, define SLAs by severity, require root cause analysis, and set up regression detection.

## Implementation

### Severity Classification and SLAs
```
P1 — Critical (service down, data loss, security incident)
  → Alert: PagerDuty on-call page
  → Response: 15 minutes
  → Resolution target: 1 hour

P2 — High (feature broken for all users, payment failing)
  → Alert: Slack #incidents channel
  → Response: 1 hour
  → Resolution target: 4 hours

P3 — Medium (feature broken for some users, degraded UX)
  → Alert: Slack #engineering daily digest
  → Response: 4 hours
  → Resolution target: 48 hours

P4 — Low (cosmetic issues, edge case failures, < 5 affected users)
  → Alert: Sentry dashboard only
  → Response: next sprint
```

### Error Grouping by Fingerprint
Sentry groups errors by stack trace by default. Override when the default grouping produces false duplicates:
```typescript
// In beforeSend:
if (event.exception?.values?.[0]?.type === "TypeError") {
  // Group by error message + top frame, not full stack trace
  event.fingerprint = [
    event.exception.values[0].value ?? "unknown",
    event.exception.values[0].stacktrace?.frames?.slice(-1)[0]?.filename ?? "unknown",
  ];
}
```

### Triage Runbook
When a new error group appears:
1. **Assign owner** — the team member who last touched the affected code owns the initial investigation
2. **Classify severity** — based on user impact (how many affected) and business impact (which features broken)
3. **Reproduce locally** — use Sentry's breadcrumbs and request context to reproduce
4. **Root cause analysis** — write a one-paragraph answer to: what went wrong, why it wasn't caught before deployment, how we'll prevent recurrence
5. **Fix and verify** — deploy fix, mark Sentry issue as resolved, monitor for 24h to confirm no regression

### Regression Detection Setup (Sentry)
- Enable "Regression" alert: triggers when a previously-resolved issue reappears
- Pin the resolution to a release: "Resolved in 1.4.2" — Sentry won't re-alert for that release, but will alert if the issue appears in 1.4.3+
- Regression alerts go to the same channel as new issues but with higher urgency

### RCA Template
```markdown
## Root Cause Analysis: [Error Title]

**Error group**: [Sentry issue URL]
**Severity**: P2
**Affected users**: ~450 over 3 hours

### What happened
[Concise description of the failure]

### Why it wasn't caught
[Why tests/monitoring didn't catch it before production]

### Fix applied
[What changed in the code]

### Prevention
- [ ] Add test covering this case
- [ ] Add alert for [metric] exceeding threshold
```

## Key Rules
- Every new error group needs an owner within the response SLA — unowned issues get ignored indefinitely
- Classify severity by user impact, not by how scary the stack trace looks — a TypeError affecting 5 users is P4, not P1
- Use Sentry breadcrumbs to capture the user action sequence before the error — without breadcrumbs, reproduction is guesswork
- Resolve issues in Sentry with a release version — not "resolve all" — so regression detection works correctly
- Write even a brief RCA for P1/P2 issues — the discipline of explaining what went wrong is what prevents recurrence
- Filter out known noise before the team sees it: `ignoreErrors`, `denyUrls` for known bot patterns and browser extensions
- Review the "regression" alert queue weekly — regressions indicate systemic problems in the test coverage or deployment process
