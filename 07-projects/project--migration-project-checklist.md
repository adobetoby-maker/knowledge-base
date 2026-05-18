# Project: Data Migration Project Checklist

## Overview
Data migrations fail in three ways: data is lost or corrupted silently, the migration takes far longer than estimated (causing extended downtime), or the rollback is not exercised before it's needed. The checklist prevents all three by requiring dry runs in staging, a tested rollback plan, and validation queries that catch corruption before cutover is declared complete.

## Phase 1 — Discovery and Planning

- [ ] Source data audit: row counts per table, null rates on key fields, enum value distributions, data anomalies (orphaned FK records, duplicate primary keys, max field lengths)
- [ ] Data mapping document: source field → destination field, transformation rules, handling of nulls and edge cases
- [ ] Identify high-risk mappings: fields that change type, fields that split/merge, fields that are dropped
- [ ] Estimated migration duration: test on a representative sample (1% of data) and extrapolate
- [ ] Decision: zero-downtime migration (dual writes) vs maintenance window migration (downtime)
- [ ] Stakeholder sign-off on approach and downtime window (if applicable)

## Phase 2 — Staging Dry Run

- [ ] Set up staging environment with production-like data volume (not a small sample)
- [ ] Restore production snapshot to staging source
- [ ] Run migration script against staging
- [ ] Validate results (see Validation section)
- [ ] Document all issues found; fix migration script
- [ ] Repeat dry run until clean pass
- [ ] Measure actual migration duration on staging; add 50% buffer for production estimate

## Zero-Downtime Migration Pattern (if applicable)

1. Deploy new schema alongside old (additive: new tables/columns)
2. Deploy code that writes to both old and new (dual write)
3. Backfill historical data from old to new (in batches, rate-limited)
4. Validate new schema has all data
5. Switch reads to new schema
6. Remove dual write (write new only)
7. Remove old schema (separate, delayed step)

- [ ] Dual write logic tested for all write paths (not just the main path)
- [ ] Backfill job is idempotent (safe to re-run)
- [ ] Read switchover is feature-flagged (fast rollback)

## Validation Queries

Define before running the migration. Run after migration completes before declaring success:

- [ ] Row count matches: `SELECT COUNT(*) FROM source` = `SELECT COUNT(*) FROM destination`
- [ ] Spot checks: sample 100 random records, compare source and destination field by field
- [ ] Null check: any not-null columns in destination have no nulls
- [ ] FK integrity: all foreign keys in destination resolve to valid parent records
- [ ] Business logic validation: key aggregates match (total revenue, total users, etc.)
- [ ] Application smoke test: create/read/update/delete through the application layer, not just SQL

## Rollback Plan

- [ ] Rollback plan documented before cutover begins
- [ ] Rollback procedure tested in staging (not just written)
- [ ] Point-in-time snapshot taken immediately before cutover (not just nightly backup)
- [ ] Rollback decision criteria defined: what condition triggers rollback vs continue-and-fix?
- [ ] Rollback time estimated (if rollback takes 3 hours, that extends the outage window)

## Cutover Checklist

- [ ] Announce maintenance window to affected users (minimum 48 hours notice for business-facing)
- [ ] Take final snapshot of production source immediately before migration
- [ ] Enable maintenance mode (or stop writes) at the agreed time
- [ ] Run migration script
- [ ] Run validation queries
- [ ] Run application smoke tests
- [ ] Declare success (or execute rollback)
- [ ] Disable maintenance mode
- [ ] Post-migration confirmation to stakeholders

## Post-Migration Monitoring

- [ ] Monitor error rates for 24–72 hours post-migration (elevated errors = data issue)
- [ ] Monitor slow queries (schema changes often reveal missing indexes)
- [ ] Keep source data intact for N days (rollback window — don't delete immediately)
- [ ] Schedule old schema cleanup after rollback window closes

## Key Rules

- Dry run in staging with production-scale data is mandatory — small-sample tests miss scale problems
- Rollback must be tested before cutover day — an untested rollback will fail when you need it most
- Snapshot immediately before migration starts (nightly backup may be 23 hours old)
- Validation queries must run before declaring success — never assume the script ran correctly
- Keep source data intact for at least 2 weeks post-migration before cleanup
- Dual-write pattern is strongly preferred over maintenance windows for customer-facing systems
