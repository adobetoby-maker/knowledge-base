# Principle: Feature Flags

## What They Solve

Deploy code to production without turning it on. Enables: dark launches, A/B tests, gradual rollouts, kill switches for broken features. Decouples deploy from release.

## Implementation Approaches

| Approach | Best for | Latency |
|----------|---------|---------|
| Environment variables | Server-only features, infra toggles | 0ms (build-time) |
| Supabase/DB table | Simple flags, self-hosted | ~5ms per read |
| PostHog Feature Flags | A/B tests, % rollouts, user targeting | ~10ms first call |
| Cloudflare KV | Edge-evaluated flags, global | ~1ms at edge |

## Pattern 1: Environment Variable Flags

```ts
// Simplest — redeploy to change
export const FLAGS = {
  NEW_CHECKOUT: process.env.FEATURE_NEW_CHECKOUT === 'true',
  MAINTENANCE_MODE: process.env.MAINTENANCE_MODE === 'true',
}

// Usage
if (FLAGS.NEW_CHECKOUT) {
  return <NewCheckout />
}
```

Tradeoff: requires redeploy to toggle. Use for infra-level flags (enable new auth system, maintenance mode).

## Pattern 2: Database-Backed Flags

```sql
CREATE TABLE feature_flags (
  name       TEXT PRIMARY KEY,
  enabled    BOOLEAN NOT NULL DEFAULT FALSE,
  rollout_pct INTEGER DEFAULT 100,  -- % of users to show feature
  note       TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

```ts
// lib/flags.ts
const flagCache = new Map<string, { value: boolean; expiresAt: number }>()
const CACHE_TTL_MS = 30_000  // 30 second cache — flags don't change frequently

export async function isEnabled(flagName: string, userId?: string): Promise<boolean> {
  const cached = flagCache.get(flagName)
  if (cached && cached.expiresAt > Date.now()) return cached.value

  const { data } = await supabase
    .from('feature_flags')
    .select('enabled, rollout_pct')
    .eq('name', flagName)
    .single()

  if (!data?.enabled) {
    flagCache.set(flagName, { value: false, expiresAt: Date.now() + CACHE_TTL_MS })
    return false
  }

  // Percentage rollout using stable hash of userId
  let enabled = data.enabled
  if (data.rollout_pct < 100 && userId) {
    const hash = Array.from(userId).reduce((acc, c) => acc + c.charCodeAt(0), 0)
    enabled = (hash % 100) < data.rollout_pct
  }

  flagCache.set(flagName, { value: enabled, expiresAt: Date.now() + CACHE_TTL_MS })
  return enabled
}
```

Cache flags in module scope — they don't change per-request. The 30-second TTL means a flag toggle takes effect within 30 seconds without a deploy.

## Pattern 3: PostHog Feature Flags (For % Rollouts)

```tsx
// Client-side
import { useFeatureFlagEnabled } from 'posthog-js/react'

function PaymentForm() {
  const useNewFlow = useFeatureFlagEnabled('new-payment-flow')
  return useNewFlow ? <NewPaymentFlow /> : <OldPaymentFlow />
}
```

```ts
// Server-side
const isEnabled = await serverPosthog.isFeatureEnabled('new-payment-flow', userId)
```

Use PostHog flags when you need: percentage rollouts, user cohort targeting (e.g., only users on Pro plan), A/B test tracking with analytics.

## Rollout Strategy

```ts
// Safe rollout sequence
// Week 1: Internal only (specific user IDs)
// Week 2: 5% of users
// Week 3: 25%
// Week 4: 100%
// Week 5: Remove flag, clean up old code path

// Rollout is stable (same user always sees same value) if based on userId hash
```

## Kill Switch Pattern

Always add a kill switch for risky features:

```ts
// New ML-powered pricing (risky — may produce unexpected values)
async function calculatePrice(item: Item): Promise<number> {
  const useML = await isEnabled('ml-pricing')

  if (useML) {
    try {
      return await mlPriceModel.predict(item)
    } catch (err) {
      // Auto-fallback if ML fails
      console.error('ML pricing failed, using fallback:', err)
    }
  }

  return legacyPriceCalculation(item)
}
```

Kill switch + fallback: if ML pricing produces errors, disable the flag in DB and all users instantly get the legacy calculation.

## Flag Naming Convention

```
FEATURE_*     — user-facing feature flags
INFRA_*       — infrastructure toggles
EXPERIMENT_*  — A/B tests
KILL_*        — emergency kill switches
```

## Cleaning Up Flags

Feature flags accumulate. Audit and remove:
- After full 100% rollout: delete flag, delete old code path
- After A/B test concludes: delete the losing variant's code + flag
- Never leave flags that are always `true` in code — they become dead code

Flag debt is a real problem in large codebases. Treat flags like temporary branches — they have a planned end date.
