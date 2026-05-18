# Skill: Zero-Downtime Deployment

## Purpose
Deploy new application versions without dropping requests or breaking in-flight operations. The main failure modes are: running DB migrations that break the old code before the new code is live, and cutting over too fast so in-flight requests hit mismatched code/schema.

## The Fundamental Rule: Separate Migration from Deployment
Database migrations and code deployment are two different operations. They must be sequenced correctly:

1. **Phase 1 — Migrate (backward-compatible only)**: Deploy migration that both old and new code can run against. Old code keeps working. New columns are nullable or have defaults. Old columns are not yet dropped.
2. **Phase 2 — Deploy code**: Roll out new application version. Both old and new instances may run briefly during rollout. The schema supports both.
3. **Phase 3 — Cleanup migration** (days/weeks later): Drop old columns, remove compatibility shims.

Never combine a breaking schema change with a code deploy in one step.

### What "Backward-Compatible Migration" Means
- Adding a nullable column: safe
- Adding a column with a default: safe
- Renaming a column: **NOT safe** — add new column, migrate data, dual-write in code, then drop old column across three separate deploys
- Dropping a column: NOT safe until no running code references it
- Adding an index `CONCURRENTLY`: safe (Postgres)
- Adding NOT NULL without a default: NOT safe — add nullable, backfill, add constraint separately

## Health Check Endpoint
Every service needs `GET /health` returning 200 when ready to receive traffic, non-2xx when not. Include checks for: DB connectivity, Redis connectivity, any critical external dependency. The load balancer or orchestrator uses this to route traffic.

Do not include slow checks in the health endpoint — it must respond in <100ms or the load balancer will mark the instance unhealthy during startup.

Separate `/health/live` (is the process running?) from `/health/ready` (is it ready for traffic?). Kubernetes and most LBs can use both.

## Rolling Deployment
The default strategy: replace instances one by one. At any point, old and new code coexist. Works well when the schema change is backward-compatible (Phase 1 above was done).

- Set `maxUnavailable: 0` and `maxSurge: 1` in Kubernetes to ensure no capacity loss
- Wait for the new instance to pass readiness checks before killing the old one
- Keep at least one old instance running until new instances prove healthy

## Blue-Green Deployment
Spin up an entire parallel environment, run smoke tests, then flip traffic. Zero risk of version mixing. More expensive (double infrastructure during cutover). Best for: major releases, stateful services, anything where coexistence is risky.

Cutover: atomic DNS/load balancer switch or feature flag at the edge. Keep blue environment running for 15 minutes post-cutover before teardown — rollback is instant if needed.

## Rollback Procedure
Define rollback before deploying, not after something breaks:

1. For rolling: set deployment image back to previous tag. Kubernetes does this in seconds.
2. For blue-green: flip traffic back to blue environment.
3. **Schema rollback is hard** — which is why Phase 1 migrations must be backward-compatible. If you need to undo a migration, add a new migration that reverses it (never manually edit the DB).
4. Log the rollback event with timestamp, reason, and who triggered it.

## Checklist Before Every Deploy
- [ ] All DB migrations are backward-compatible with the previous code version
- [ ] `/health/ready` endpoint tested locally
- [ ] Rollback procedure documented and tested on staging
- [ ] Feature flag for risky new behavior (can be turned off without redeploying)
- [ ] Monitoring alert thresholds in place (error rate, latency p99)
- [ ] Deployment window communicated (avoid peak hours for risky changes)

## Key Rules
- **Migrate first, deploy second** — the schema must tolerate both old and new code simultaneously
- **Never drop columns in the same deploy that removes their usage** — always a separate cleanup phase
- **Health endpoint must be fast** — if it's slow, the LB marks you unhealthy on every startup
- **Define rollback before deploying** — not while an incident is ongoing
- **Blue-green costs double temporarily** — it's worth it for major releases; overkill for patches
- **`CONCURRENTLY` for all new indexes** — a regular `CREATE INDEX` locks the table
