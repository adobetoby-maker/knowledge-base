# Principle: Post-Mortem Culture

## Overview
Blameless post-mortems operate on a fundamental premise: no reasonable, experienced engineer deliberately causes an incident. If they deployed broken code or made a bad decision, the system allowed it. The system's job is to prevent human mistakes from becoming production incidents. When the post-mortem outcome is "Bob shouldn't have done that," nothing changes — Bob will still make mistakes, and so will the next person. When the outcome is "our CI doesn't test this code path," you get a systemic fix that protects everyone.

## Key Points

### The Timeline
Start every post-mortem with a factual timeline in UTC:
```
2025-11-14 UTC
14:32 — Deploy v2.4.1 to production (user-service)
14:38 — First alert: P95 error rate on /api/orders crosses 5%
14:41 — On-call engineer (Sarah) acknowledges alert
14:45 — Sarah identifies deploy correlation in Datadog
14:47 — Sarah initiates rollback to v2.4.0
14:51 — Rollback complete; error rate returns to baseline
14:52 — Incident resolved
Total impact: 14 minutes, ~3,200 affected requests
```

Timeline facts only — no attributions, no judgments, no "Sarah should have."

### Root Cause vs. Proximate Cause
```
Proximate cause: "v2.4.1 contained a null pointer exception in the order handler"
Root cause:     "The function was refactored 3 weeks ago; the test that covered this
                 path was deleted as 'redundant' during the refactor. CI passed.
                 The code path is only hit with certain payment methods not covered
                 by staging fixtures."
```

The proximate cause is what failed. The root cause is why the system allowed it to fail. The proximate cause points at code. The root cause points at process, testing, tooling, or system design.

Use "5 Whys" to reach the actual root cause:
```
Why did users see errors? → Null pointer exception in order handler
Why was there a null pointer? → payment.method was unexpectedly null
Why was it null? → A refactor changed the upstream service's response shape
Why didn't tests catch it? → No test covered that code path
Why was there no test? → It was deleted during refactor as "redundant"
Why was the deletion not caught? → Code review didn't check coverage for deleted tests
```
Root cause: code review process doesn't verify test coverage after test deletion.

### Action Items
Every contributing factor should produce a corrective action:
```
| Action                                          | Owner  | Due     |
|------------------------------------------------|--------|---------|
| Add integration test for all payment methods   | @alice | Nov 21  |
| Add staging fixture for "pay-later" method     | @bob   | Nov 21  |
| Add PR checklist: "have you deleted any tests?"| @carol | Nov 28  |
| Add test coverage gate to CI (no regression)   | @alice | Dec 5   |
```

Action items without owners and due dates are aspirations. Owners and dates make them commitments.

### What Blameless Means in Practice
Blameless does not mean:
- Pretending mistakes don't happen
- Ignoring that a specific person deployed the change
- Avoiding accountability for action items

Blameless means:
- The person who deployed is not the problem to be solved
- Systems that allowed the mistake are the problem to be solved
- People speak up about near-misses because they will not be blamed

A culture where engineers fear post-mortems produces hidden near-misses — incidents that almost happened but were quietly fixed without documentation. Those are lost learning opportunities.

### Post-Mortem Cadence
- Every P0 (service down, data loss): mandatory, within 48 hours of resolution
- Every P1 (significant degradation, SLA miss): mandatory, within 5 business days
- Significant near-misses: encouraged, even if no user impact
- P2 and below: optional, based on whether there are systemic learnings

Post-mortem documents should be:
- Searchable by the whole organization
- Linked from the incident ticket
- Reviewed in a meeting (not just read async) for P0s

### Metrics for Post-Mortem Program Health
- Average time to write post-mortem after incident (target: < 48 hours for P1)
- % of action items completed by due date
- Number of repeat incidents of same class (should trend to zero)

## Key Rules
- "Human error" as a root cause is a failed post-mortem — systems must be designed to tolerate human error
- The timeline is facts only; attribution and judgment belong in the contributing factors section, not the timeline
- Every contributing factor needs an action item; contributing factors without actions are observations, not improvements
- Action items need an owner (person, not team) and a due date
- Post-mortems are reviewed in a meeting, not just written to satisfy a process
- Publish post-mortems to the whole organization, not just the affected team — others can learn and apply the same fixes
- Track action item completion; an action item that never closes is evidence the process is performative
