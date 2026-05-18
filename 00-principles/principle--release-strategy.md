# Principle: Release Strategy

## Overview
Conflating deployment with release is the root cause of "big bang" launches, deployment-night anxiety, and multi-hour rollback procedures. When code ships to production and becomes visible to users simultaneously, every deploy is a release event carrying its full risk. Separating these two moments gives teams the ability to deploy continuously and release deliberately.

## The Distinction

| Event | What happens | Who controls it |
|---|---|---|
| **Deploy** | Code lands on production servers | CI/CD pipeline (automatic) |
| **Release** | Users can see/access the feature | Product decision (deliberate) |
| **Dark launch** | Deployed + running in production, but output is discarded or suppressed | Engineering (for performance testing) |

## Why Conflation Creates Risk

**The coupled deploy/release model:**
1. Feature is "done" on Friday
2. Deploy happens Friday 4pm
3. 50,000 users immediately see the new checkout flow
4. Bug found at 4:30pm
5. Rollback requires a redeployment (5–20 minutes), or worse, a hotfix

**The decoupled model:**
1. Feature deploys Monday, disabled by flag
2. Internal team tests Thursday
3. 5% of users see it Friday via flag rollout
4. Metrics look good; 100% Monday morning
5. Bug found: flip flag off in 10 seconds, zero redeployment

## Dark Launches for Performance Testing

Before releasing a new query or service, run it in production with real data but discard the output:
```typescript
async function getRecommendations(userId: string) {
  const [legacyResult, newResult] = await Promise.allSettled([
    legacyRecommendations(userId),
    newRecommendations(userId),  // running but output ignored
  ]);

  // Log performance of new implementation
  if (newResult.status === 'fulfilled') {
    metrics.record('new_recommendations_latency', newResult.value.latency);
  }

  // Serve only legacy result to users
  return legacyResult.value;
}
```
This validates real-world performance before any user sees the new path.

## Feature Flag Lifecycle

A feature flag without an expiry date becomes permanent tech debt. Track lifecycle at creation:

```typescript
const flags = {
  'new-checkout': {
    enabled: false,
    owner: 'payments-team',
    created: '2025-01-15',
    target_removal: '2025-03-01',  // set at creation
    state: 'rolling-out',  // draft → internal → canary → ga → cleanup
  }
};
```

**States:**
- `draft`: deployed, disabled for all users
- `internal`: enabled for team members only
- `canary`: 1–20% of users
- `ga`: 100% of users, flag removal scheduled
- `cleanup`: code branch removed, flag deleted

## Release Communication

The release event (not the deploy) triggers:
- User-facing changelog
- Marketing announcement
- Support team notification
- Monitoring alert thresholds adjusted for new traffic patterns

Release timing is a product decision. Deploy timing is an engineering decision. These should not be coupled.

## Rollback Strategy by Type

| Scenario | Rollback mechanism | Time |
|---|---|---|
| Feature flag controls it | Flip flag | Seconds |
| Canary release | Reduce to 0% | Minutes |
| Full deploy, no flag | Revert commit + redeploy | 5–15 minutes |
| DB migration deployed | Compensating migration | 30+ minutes |

The further right in this table, the more expensive the rollback. Feature flags push every release to the leftmost column.

## Key Rules
- Deploy should be boring and frequent; release is a business event
- Every user-facing feature deserves a feature flag during initial rollout
- Dark launches validate production performance before users are affected
- Set a removal date for every feature flag at the time of creation
- Release communication (changelog, marketing) is triggered by the release, not the deploy
- Rollback without redeployment (via flag) is 10x faster than rollback via CI/CD
