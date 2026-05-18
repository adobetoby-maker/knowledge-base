# Principle: Progressive Delivery

## Overview
Progressive delivery separates the act of deploying code from the act of releasing it to users. This gives teams the ability to expose new features to a small percentage of real traffic, measure impact, and roll back instantly without a redeployment. The key insight: a bug found at 5% traffic affects 5% of users; a bug found at 100% affects everyone.

## The Spectrum of Techniques

### Feature Flags (controlled release)
Deploy code disabled by default. Enable for specific users, groups, or percentages.
- Internal team → 1% → 10% → 50% → 100%
- Kill switch: disable instantly without a deploy
- Tooling: LaunchDarkly, GrowthBook, Unleash, custom DB-backed flags

```typescript
if (featureFlags.isEnabled('new-checkout', userId)) {
  return <NewCheckout />;
}
return <LegacyCheckout />;
```

### Canary Releases
Route a percentage of real production traffic to the new version.
- 5% of requests hit the new service instance; 95% hit the old
- Not the same as staging — canary uses real data and real users
- Must measure before expanding: error rate, p95 latency, business metrics
- Tooling: Kubernetes traffic splitting, Vercel skew protection, nginx upstream weights

### Blue-Green Deployment
Two identical environments (blue = live, green = new version). Cut over 100% of traffic at once.
- Instant rollback: flip traffic back to blue
- Both environments must run simultaneously (cost implication)
- Database compatibility must exist between both versions

## The Kill Switch Requirement

A canary without a kill switch is dangerous. Before traffic reaches the new version:
1. Feature flag exists and defaults to off
2. On-call runbook includes the flag name and how to disable it
3. Alert threshold is set: if error rate > 0.5%, page on-call
4. Kill switch is tested in staging before canary starts

## Deployment vs Release

| Term | Definition |
|---|---|
| Deploy | Code is on the server, but no user sees it |
| Release | Users can access the feature |
| Dark launch | Deployed + running, but output is discarded (used to test performance) |

This distinction matters for incident response: "we deployed 3 hours ago but released 5 minutes ago" correctly narrows the blame window.

## Measuring a Canary

Before increasing traffic percentage, measure for at least 15 minutes:
- **Error rate**: canary group vs control group (same metric, not absolute)
- **p95 latency**: not average — tail latency degrades first
- **Business metric**: conversion, checkout success, signup completion
- **Resource utilization**: memory, DB connections, CPU

If any metric degrades beyond threshold: reduce to 0% immediately, do not try to fix forward.

## Canary Anti-Patterns
- Running canary against staging traffic (not real users)
- Expanding percentage without measuring the previous tier
- Canary duration too short (< 15 minutes misses slow memory leaks, cron effects)
- No automatic rollback trigger — relying on manual monitoring overnight

## Key Rules
- The kill switch must exist before any real user traffic reaches the canary
- Canary = 5% real traffic; measure error rate and latency before expanding
- Deployment and release are separate events; track them separately in incident timelines
- A feature flag used for > 90 days becomes tech debt — schedule cleanup at creation time
- Always measure the same metric for canary and control, not absolute values
