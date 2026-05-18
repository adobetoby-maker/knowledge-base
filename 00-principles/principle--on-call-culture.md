# Principle: On-Call Culture

## Overview
On-call is only sustainable when alerts are honest about what they represent. An alert that fires for something a human cannot or should not act on right now is not an alert — it is noise. Sustained noise trains engineers to ignore their phones, which is exactly the wrong response during a real incident. The quality of your on-call rotation is measured not by how many alerts you have, but by how often an alert firing means a human must do something in the next 30 minutes.

## Key Points

### Alert Design: Actionable vs. Informational
Every alert should answer: "What action does the on-call engineer take when this fires?"
- **Actionable alert:** "P95 latency on /api/checkout has been above 2s for 5 minutes" → investigate, rollback, scale
- **Noise:** "CPU spiked to 60% for 30 seconds" → no action needed, transient
- If the answer is "look at it and decide later," it belongs in a dashboard, not a pager

### Alert Fatigue Is a Safety Problem
Alert fatigue follows a predictable path:
1. Too many low-signal alerts → engineers learn to dismiss pages quickly
2. Dismissal becomes muscle memory
3. A real P0 arrives → engineer dismisses it by habit before fully reading it
4. SLA missed, data lost, or users impacted

Silence noisy alerts aggressively. The risk of missing a real alert is lower than the risk of habituated dismissal from noise.

### On-Call Tooling
- **PagerDuty / OpsGenie rotation:** distribute pages fairly across the team; no single person carries the burden long-term
- **Escalation policy:** primary → secondary → manager, with timeout between each
- **Overrides:** people on vacation should not be paged; cover-swap process must be easy
- **Schedules that match timezones:** 24/7 coverage split across timezones reduces sleep-disrupting pages

### Runbooks for Every Alert
A runbook is the set of steps an on-call engineer should follow when a specific alert fires:
```markdown
## Alert: High error rate on payment service
**Threshold:** >1% of requests returning 5xx for 5+ minutes
**Impact:** Customers unable to complete purchases
**Steps:**
1. Check recent deployments: [Deployment link]
2. Check DB connection pool: [Dashboard link]
3. Check Stripe status: https://status.stripe.com
4. If deployment is cause: rollback with `./scripts/rollback.sh payment-service`
5. Page #team-payments if not resolved in 10 minutes
```
A runbook that says "investigate and use judgment" is not a runbook.

### Post-Mortems for Every P1/P0
After every significant incident:
1. Write a timeline of what happened (UTC timestamps, not vague "then we...")
2. Identify contributing factors (not "Bob made a mistake")
3. Assign action items with owners and due dates

The goal: the same class of incident should not recur. If it does, the post-mortem produced insufficient action.

### Measuring On-Call Health
- Pages per week per engineer: should trend down over time, not up
- Mean time to acknowledge (MTTA): <5 minutes for P1
- Mean time to resolve (MTTR): track separately per service
- Alert-to-action ratio: what % of pages required actual human intervention?

## Key Rules
- Page for symptoms (high latency, errors, failed health checks), not causes (high CPU by itself)
- Every alert must have a runbook linked in the alert body
- If an alert fires 3+ times per week with no required action, silence it or remove it
- On-call rotation must be visible to the whole team — no implicit "that's Joe's job"
- Post-mortems are blameless; "human error" as a root cause is a failure of the post-mortem
- Never page for things that have automatic recovery and don't require human decisions
- Schedule regular rotation reviews: which alerts are noisy? Which runbooks are stale?
