# Principle: Feature Flag Lifecycle

## Overview

Feature flags accumulate. A flag created for a gradual rollout that's been at 100% for six months is dead code wearing a safety costume. Managing flag lifecycle — from creation to cleanup — prevents the codebase rot that comes from flags that outlive their purpose.

## Flag Lifecycle Stages

```
Create → Test (0%) → Ramp (10% → 50% → 100%) → Remove
                              ↘ Kill (if rollback needed)
```

Every flag should have an owner and an expected removal date at creation. If neither exists, the flag will never be cleaned up.

## Naming Convention

```ts
// Good: describes what changes, not implementation detail
const flags = {
  NEW_CHECKOUT_FLOW: 'new-checkout-flow',      // feature flag
  ENABLE_DARK_MODE: 'enable-dark-mode',        // rollout flag
  KILL_LEGACY_SEARCH: 'kill-legacy-search',    // kill switch
} as const

// Bad: doesn't communicate direction or purpose
const flags = {
  SEARCH_V2: 'search-v2',
  EXPERIMENT_42: 'experiment-42',
}
```

## Default Values in Code

```ts
// Always have a safe default — the flag server might be unavailable
function isFeatureEnabled(key: string, defaultValue: boolean): boolean {
  try {
    return featureFlags.isEnabled(key)
  } catch {
    return defaultValue  // safe fallback
  }
}

// New risky feature: default OFF
const useNewPaymentFlow = isFeatureEnabled('new-payment-flow', false)

// Kill switch for bad behavior: default ON (service continues)
const legacySearchEnabled = isFeatureEnabled('legacy-search', true)
```

## Tracking Owners and Sunset Dates

```ts
// Document flags at definition time, not just in the flag tool
const FLAG_REGISTRY = {
  'new-checkout-flow': {
    owner: 'payments-team',
    createdAt: '2026-01-15',
    sunsetDate: '2026-03-01',
    purpose: 'Gradual rollout of Stripe Payment Element checkout',
    status: 'ramping',
  },
} as const
```

A monthly audit of flags past their sunset date prevents accumulation. The audit should output a list of dead flags as a Slack message or GitHub issue.

## Cleanup Process

```ts
// Before removing a flag at 100%, verify it's safe to hard-code
// Step 1: Set flag to 100% for 2+ weeks, monitor for errors
// Step 2: Remove the flag check, replace with the enabled branch
// Step 3: Remove the flag from the flag tool

// BEFORE:
if (isFeatureEnabled('new-checkout-flow')) {
  return <NewCheckout />
} else {
  return <OldCheckout />
}

// AFTER cleanup:
return <NewCheckout />
// Delete OldCheckout component
```

## Key Rules

- Every flag needs an owner and sunset date at creation — without these, flags never get cleaned up.
- Stale flags at 100% that still branch in code are a hidden complexity tax — they block future refactoring.
- Default values should be "safe" (the current behavior), not "experimental" — flag server downtime shouldn't activate beta features.
- Kill switches should default to the safe (service-on) state — a down flag server shouldn't disable a critical feature.
- Treat flag removal as a first-class task — schedule it in the same sprint as the rollout completion.
