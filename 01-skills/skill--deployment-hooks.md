# Deployment Hooks

Pre- and post-deployment hooks automate the steps that must happen around a release. When done correctly, the sequence is deterministic: migrations run before new code serves traffic, smoke tests validate before promoting to production.

## The Correct Deployment Order

```
1. pre-deploy: run migrations
2. pre-deploy: warm caches (optional)
3. deploy: swap new code into service
4. post-deploy: smoke tests
5. post-deploy: notify Slack / PagerDuty
6. (on failure): trigger rollback
```

Migrations always precede code deployment. New code must be compatible with the new schema — if migrations run after deploy, there's a window where new code tries to use columns that don't exist yet. This window causes 500s under real traffic.

The corollary: migrations must be backward-compatible with the previous version of the code during the transition window. Don't drop a column in the same migration that adds the replacement — drop it one release later, after all instances are on the new code.

## Pre-Deploy: Migrations

Run database migrations in the pre-deploy hook as a blocking step. If migrations fail, abort the deployment. A failed migration with new code deployed is a production incident; a failed migration with old code still serving is a recoverable error.

Vercel's `postinstall` hook or a `build` command step work for this. In CI/CD pipelines, make the migration step a prerequisite job that blocks the deploy job on failure.

```bash
# pre-deploy hook example
npx prisma migrate deploy && echo "Migrations OK" || exit 1
```

## Pre-Deploy: Cache Warming

For apps that serve expensive computed results from cache, deploy to a warm cache or pre-warm after deploy. A cold cache after deployment means your first real users absorb the cost. Pre-warm by hitting key pages or endpoints immediately after the new instance starts, before it receives traffic.

## Post-Deploy: Smoke Tests

Smoke tests are the safety net between deployment and traffic promotion. They verify the essentials: homepage loads (200), API health endpoint responds, auth flow works, a key user journey completes. They are not comprehensive test suites — they run in under 60 seconds and check that the deployment isn't broken.

If a smoke test fails, the deployment should not promote (roll forward or roll back depending on your strategy). A failed smoke test that still goes live because the alert was ignored is a process failure, not just a code failure.

## Post-Deploy: Notify

Send a deployment notification to Slack or your incident channel: what was deployed, who deployed it, what changed (link to PR/commit), and success/failure status. This creates an audit trail that helps diagnose "when did X break" during incidents.

## Rollback Trigger Conditions

Automatic rollback triggers should be narrow and high-confidence: error rate spikes above baseline by more than 2x within 5 minutes of deploy, p99 latency exceeds threshold, health check fails. Don't trigger rollback on a single error — wait for a rate.

Manual rollback must be one command, documented and rehearsed. The person on call at 2am should not be reading documentation to roll back.

## Timeout Handling

Give hooks explicit timeouts. A migration that runs for 30 minutes is holding a lock, not making progress. Set a timeout (migrations: 10 minutes; smoke tests: 2 minutes) and fail loudly on timeout — a hung hook that never resolves is worse than a fast failure.

## Key Rules

- Migrations always run before deploy, never after — they must be backward-compatible with previous code
- Migrations failure must abort the deploy; don't deploy over a failed migration
- Smoke tests run post-deploy before promoting traffic; auto-rollback on failure
- Post-deploy Slack notification creates an incident audit trail — never skip it
- All hooks must have explicit timeouts; silence and hung processes are failures
- Rollback procedure must be one documented command, tested in staging monthly
