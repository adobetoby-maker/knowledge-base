# Review: Incident Response Runbook Template

## Overview
Runbooks exist so that the engineer paged at 2am can act without needing to think from scratch. A runbook that lives in Confluence and isn't linked from the alert is nearly useless — the engineer won't find it in time. Every alert should link directly to its runbook. The runbook should fit on one page; anything longer won't be read under pressure.

## Implementation / Key Points

### Runbook Template
```markdown
# Runbook: [Service/Alert Name]

## Alert Link
[Link to alert in monitoring tool]

## Severity
P[1/2/3] — [brief description of impact]

## Acknowledge SLA
- P1: 5 minutes
- P2: 30 minutes  
- P3: next business day

## What Triggered This
[Plain-language description of what the alert fires on]
Example: Error rate on /api/checkout exceeded 1% for 5 minutes

## Immediate Triage (< 5 min)
1. Check status page: [link]
2. Check upstream dependencies: [link to dependency dashboard]
3. Check deployment log: [link] — was there a recent deploy?
4. Check error logs: [link] — what error is recurring?

## Common Causes + Fixes
| Symptom | Cause | Fix |
|---|---|---|
| 503 errors | DB connection pool exhausted | Restart app pod; scale if sustained |
| 500 errors after deploy | Bug in new code | Roll back: [rollback command] |
| Latency spike, no errors | Slow query | Check slow query log: [command] |

## Escalation
If not resolved in 30 minutes: page [escalation contact]
Secondary on-call: [contact]

## Resolution Steps
1. Mitigate (stop the bleeding)
2. Communicate on status page
3. Find root cause
4. Fix or schedule fix
5. Update status page: resolved
6. File post-mortem within 48 hours

## Post-Mortem Template Link
[link]
```

### Severity Definitions
| Level | Impact | Response SLA | Who Gets Paged |
|---|---|---|---|
| P1 | Production down, data loss, security breach | 5 min acknowledge | On-call + manager |
| P2 | Major feature broken, significant degradation | 30 min acknowledge | On-call only |
| P3 | Minor bug, non-critical degradation | Next business day | No page, ticket |

### Incident Timeline Checklist
- [ ] **Detect** — alert fires or user reports
- [ ] **Acknowledge** — someone owns it (within SLA)
- [ ] **Assess** — determine P1/P2/P3
- [ ] **Communicate** — update status page (even "investigating")
- [ ] **Investigate** — find cause using runbook steps
- [ ] **Mitigate** — restore service (rollback, restart, scale, feature flag off)
- [ ] **Resolve** — root cause fixed or workaround in place
- [ ] **Post-mortem** — write up within 48h, update runbook

### Communication Template (Status Page)
```
[Investigating] We are investigating reports of [symptom]. Impact: [who is affected].
[Update] We have identified the cause as [X] and are working to resolve it.
[Resolved] The issue has been resolved. Root cause and prevention steps in our post-mortem.
```

### Runbook Maintenance
- Update runbook after every incident that used it
- Add any new "symptom → cause → fix" patterns discovered
- Review all runbooks quarterly for accuracy
- Runbooks live in the repo (`/docs/runbooks/`), not in a wiki that can go down

## Key Rules
- Every paging alert must link directly to its runbook — no search required
- Runbook must fit on one page; longer runbooks won't be read under pressure
- Acknowledge SLA: P1 = 5 minutes, P2 = 30 minutes
- Update the status page immediately on acknowledge, even if you have no information yet
- Mitigation (restore service) comes before root cause analysis
- Post-mortem must be written within 48 hours, while memory is fresh
- Runbooks live in the repo alongside the code, versioned together
- After every incident, update the runbook with any new patterns found
