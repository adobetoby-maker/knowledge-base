# Principle: Estimation Approach

## Overview
Point estimates for engineering work are almost always wrong because they do not account for integration, testing, interruptions, or unknown unknowns. The solution is not to estimate more accurately — it is to decompose until tasks are small enough to have known boundaries, add explicit buffers for the things that always happen, and track estimation accuracy over time to calibrate future estimates.

## Implementation / Key Points

### Decompose to Sub-4-Hour Tasks
A task estimate is reliable when the task is fully understood. Tasks longer than 4 hours almost always contain hidden subtasks. If you cannot decompose it further, you don't understand it well enough to estimate it — that's a spike, not an estimate.

```
Before: "Build payment integration" → 2 days [unreliable]

After:
- Research Stripe webhook event model → 2h
- Implement checkout session creation API → 3h
- Build webhook handler + idempotency check → 3h
- Write integration tests against Stripe test mode → 2h
- Add monitoring + error alerts → 2h
Total: 12h + 20% integration = 14.4h + 20% buffer = ~17h (2.5 days)
```

### Standard Buffers
- **+20% for integration and testing** — tasks do not combine without friction.
- **+20% for unknowns** — something unexpected always surfaces.
- Total buffer: ~44% over raw task estimates (compounding 1.2 × 1.2 = 1.44).

These buffers are not pessimism — they are calibration based on how software projects actually behave.

### Separate "Known" from "Spike Needed"
```
Known work (estimable):
- Add field to user profile form: 3h
- Write email template: 2h

Spike needed (time-box, not estimate):
- Evaluate SFTP integration options: 1-day spike
- Understand legacy auth flow before touching it: 0.5-day spike
```
A spike produces an estimate, not a deliverable. Time-box the spike, then estimate the deliverable.

### Range Estimates, Not Point Estimates
```
Bad:  "3 days"
Good: "2–4 days, more likely 3 if the auth integration is straightforward"
```
Ranges communicate uncertainty honestly. A range of 2–4 days also surfaces discussion — "what would make it 4?" is a valuable question.

### Track Accuracy
```
Sprint    | Estimated | Actual | Ratio
----------|-----------|--------|-------
Sprint 12 | 40h       | 52h    | 1.30
Sprint 13 | 40h       | 44h    | 1.10
Sprint 14 | 40h       | 48h    | 1.20
Average ratio: 1.20 → multiply all estimates by 1.20
```
After 6+ sprints, your personal average ratio becomes your calibration constant.

### "I Don't Know Yet" is Valid
"I don't know yet, I need a spike to estimate this" is more useful than a fabricated estimate. Fabricated estimates create false deadlines that consume planning decisions downstream.

## Key Rules
- Decompose all tasks to < 4 hours before estimating.
- Add 20% for integration/testing and another 20% for unknowns.
- Provide ranges, not point estimates.
- Label unknown work as "spike needed" — time-box it, don't estimate it.
- Track estimation accuracy over 6+ sprints and apply your calibration ratio.
- "I don't know yet" requires a spike, not a guess.
- Never estimate under social pressure — a bad estimate is worse than a delayed estimate.
