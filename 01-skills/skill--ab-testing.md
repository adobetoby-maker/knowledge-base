# Skill: A/B Testing

## Overview

Split test UI variations, pricing, copy, or features to measure conversion impact. Requires: experiment definition, user assignment (consistent per user), data collection, and statistical analysis.

## Experiment Architecture

```ts
interface Experiment {
  id: string                    // 'pricing-page-v2'
  variants: string[]            // ['control', 'treatment']
  weights?: number[]            // [50, 50] — equal split default
  targeting?: {
    newUsersOnly?: boolean
    countries?: string[]
    userSegment?: string
  }
}
```

## User Assignment

Assignment must be:
1. **Consistent**: Same user always gets same variant (or they notice the change)
2. **Stable**: Doesn't change when you restart the server
3. **Unbiased**: Not correlated with any user characteristic

```ts
import { createHash } from 'crypto'

function assignVariant(userId: string, experimentId: string, variants: string[], weights?: number[]): string {
  // Deterministic hash-based assignment
  const hash = createHash('sha256')
    .update(`${userId}:${experimentId}`)
    .digest('hex')

  // Convert first 8 hex chars to a number 0-100
  const bucket = parseInt(hash.slice(0, 8), 16) % 100

  // Assign based on weights (default: equal split)
  const normalizedWeights = weights ?? variants.map(() => 100 / variants.length)
  let cumulative = 0

  for (let i = 0; i < variants.length; i++) {
    cumulative += normalizedWeights[i]
    if (bucket < cumulative) return variants[i]
  }

  return variants[variants.length - 1]
}

// Always stable — same userId + experimentId → same variant
const variant = assignVariant('user-123', 'pricing-page-v2', ['control', 'treatment'])
```

## Storage and Tracking

```sql
CREATE TABLE experiment_assignments (
  user_id       UUID NOT NULL,
  experiment_id TEXT NOT NULL,
  variant       TEXT NOT NULL,
  assigned_at   TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, experiment_id)
);

CREATE TABLE experiment_events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL,
  experiment_id TEXT NOT NULL,
  variant       TEXT NOT NULL,
  event_type    TEXT NOT NULL,  -- 'impression', 'conversion', 'click'
  properties    JSONB DEFAULT '{}',
  created_at    TIMESTAMPTZ DEFAULT now()
);
```

## Middleware Assignment

```ts
// middleware.ts — assign and persist variant in cookie
export async function middleware(request: NextRequest) {
  const response = NextResponse.next()

  const ACTIVE_EXPERIMENTS = ['pricing-page-v2', 'hero-cta-test']

  for (const expId of ACTIVE_EXPERIMENTS) {
    const cookieKey = `exp_${expId}`
    if (!request.cookies.has(cookieKey)) {
      // Get or create anonymous user ID
      const userId = request.cookies.get('anon_id')?.value ?? crypto.randomUUID()
      const variant = assignVariant(userId, expId, ['control', 'treatment'])

      response.cookies.set(cookieKey, variant, { maxAge: 30 * 24 * 3600 })
      response.cookies.set('anon_id', userId, { maxAge: 365 * 24 * 3600 })
    }
  }

  return response
}
```

## React Component Usage

```tsx
'use client'
import { useExperiment } from '@/hooks/useExperiment'

function PricingPage() {
  const variant = useExperiment('pricing-page-v2')

  return (
    <div>
      {variant === 'treatment' ? (
        <AnnualPricingFirst />
      ) : (
        <MonthlyPricingFirst />
      )}
    </div>
  )
}

// Hook reads from cookie (set by middleware)
function useExperiment(experimentId: string): string {
  const cookieValue = document.cookie
    .split('; ')
    .find((row) => row.startsWith(`exp_${experimentId}=`))
    ?.split('=')[1]

  return cookieValue ?? 'control'
}
```

## Tracking Conversions

```ts
async function trackConversion(experimentId: string, variant: string, userId: string) {
  await supabase.from('experiment_events').insert({
    user_id: userId,
    experiment_id: experimentId,
    variant,
    event_type: 'conversion',
  })
}
```

## Analysis Query

```sql
-- Conversion rate by variant
SELECT
  variant,
  COUNT(DISTINCT CASE WHEN event_type = 'impression' THEN user_id END) as exposed,
  COUNT(DISTINCT CASE WHEN event_type = 'conversion' THEN user_id END) as converted,
  ROUND(
    100.0 * COUNT(DISTINCT CASE WHEN event_type = 'conversion' THEN user_id END)
    / NULLIF(COUNT(DISTINCT CASE WHEN event_type = 'impression' THEN user_id END), 0),
    2
  ) as conversion_rate
FROM experiment_events
WHERE experiment_id = 'pricing-page-v2'
GROUP BY variant
```

## When to Stop an Experiment

Minimum sample size for 80% statistical power at 5% significance:
- 5% baseline conversion, detect 20% lift: need ~2,000 per variant
- 10% baseline, detect 10% lift: need ~5,000 per variant

Use a statistical significance calculator before stopping early. "We ran it for 2 weeks and treatment looked better" is not rigorous — random variation creates false positives.

Stop early only if: (a) sample size is met AND p < 0.05, or (b) treatment is causing clear harm (conversion significantly down).

## PostHog Integration

```ts
// Simpler: use PostHog feature flags — handles assignment, tracking, and analysis
import posthog from 'posthog-js'

const variant = posthog.getFeatureFlag('pricing-page-v2')  // 'control' | 'treatment' | undefined
posthog.capture('pricing_page_viewed', { variant })
```

PostHog's flags use the same hash-based assignment under the hood and give you a dashboard without building the analysis queries yourself.
