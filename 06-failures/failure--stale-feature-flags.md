# Failure: Stale Feature Flags

## Overview
A feature flag that has been at 100% rollout for six months is not a feature flag — it is a permanent code fork with extra overhead. Stale flags make the codebase incomprehensible (which branch is the real behavior?), block refactoring (the old code path must be maintained indefinitely), and accumulate as dead weight in every deployment. Feature flags should have a defined lifespan, an owner, and a removal date.

## How Flags Go Stale

1. Feature ships at 1% → 100% over two weeks
2. Team declares success, moves to next feature
3. Nobody schedules cleanup
4. Six months later: flag is at 100%, old code path is never executed, but both branches exist
5. New engineer cannot tell which branch is canonical
6. Refactoring the flagged code requires understanding both branches and removing one

Multiply this by 50 flags and the codebase has 50 undocumented code forks.

## Required Metadata for Every Flag

Every flag should be documented with:
```typescript
// flags.ts
export const flags = {
  newCheckoutFlow: {
    description: "New 3-step checkout replacing legacy 5-step flow",
    owner: "checkout-team",
    createdAt: "2024-11-01",
    plannedRemovalDate: "2025-02-01", // 3 months after full rollout
    defaultValue: false,
    currentRollout: 100, // %
  },
};
```

When `currentRollout` hits 100%, the `plannedRemovalDate` clock starts.

## Sunset Protocol

When a flag reaches 100% and has been stable for 2+ weeks:

**Step 1: Hard-code the enabled branch**
```typescript
// Before cleanup:
if (featureFlags.isEnabled("newCheckoutFlow")) {
  return newCheckoutFlow(cart);
} else {
  return legacyCheckoutFlow(cart); // dead code
}

// After cleanup:
return newCheckoutFlow(cart); // flag removed, old branch deleted
```

**Step 2: Delete the disabled branch**
The `legacyCheckoutFlow` function and all its dependencies are deleted. This is the actual cleanup — not just removing the flag check.

**Step 3: Remove the flag from all systems**
- Remove from code
- Archive in the feature flag service (LaunchDarkly, Unleash, Statsig)
- Update documentation

## Monthly Flag Audit

Automated or manual monthly review of all active flags:
```bash
# Find flags that haven't changed in 30+ days (adapt to your flag service)
launchdarkly-cli flags list --format json | \
  jq '.[] | select(.modifiedDate < (now - 2592000)) | .key, .modifiedDate'
```

For each flag:
- Is rollout < 100%? Keep, but confirm progress plan
- Is rollout = 100% for > 2 weeks? Schedule removal sprint
- Is rollout = 0% for > 1 month (experiment abandoned)? Delete immediately

## Permanent vs Temporary Flags

Some flags are intentionally permanent: ops toggles (kill switches), regional configuration, A/B tests with indefinite life. Document these explicitly so they are excluded from the stale audit:

```typescript
export const flags = {
  // Permanent: ops kill switch, never "goes stale"
  paymentsKillSwitch: { type: "permanent", description: "Emergency disable payments" },
  
  // Temporary: remove after 2024-Q1
  newOnboardingFlow: { type: "temporary", plannedRemoval: "2024-03-31" },
};
```

## The Code Comprehension Cost

Five stale flags in one component means 2^5 = 32 theoretical states the component could be in. Engineers debugging an issue cannot tell which branches are dead. This is why stale flags have a concrete comprehension cost — not just theoretical cleanliness.

## Key Rules
- Every flag has: owner, createdAt, plannedRemovalDate, currentRollout documented
- Monthly audit of all flags — every flag at 100% for > 2 weeks is flagged for removal
- Removal means: delete the old code path, delete the flag, not just removing the check
- Permanent (ops) flags are labeled explicitly and excluded from stale audit
- Flag creation ticket links to a flag removal ticket created at the same time
- No new flag without a sunset date — this is enforced in PR review
- If the removal date passes with no action, the flag is removed by default (enabled branch wins)
