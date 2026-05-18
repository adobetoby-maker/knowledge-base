# Skill: A/B Testing Infrastructure

## Overview
A/B testing produces valid results only when assignment is deterministic and stable (same user always sees the same variant), exposure is measured before conversion, and tests run until statistical significance is reached — not stopped early when the numbers look good. Violating any of these produces false conclusions that can ship regressions.

## Implementation / Key Points

### Deterministic Assignment by User ID Hash
```ts
import { createHash } from 'crypto';

function assignVariant(userId: string, experimentId: string, variants: string[]): string {
  const hash = createHash('sha256')
    .update(`${experimentId}:${userId}`)
    .digest('hex');
  const bucket = parseInt(hash.slice(0, 8), 16) % 100;  // 0-99
  // variants = [{ name: 'control', weight: 50 }, { name: 'treatment', weight: 50 }]
  let cumulative = 0;
  for (const v of variants) {
    cumulative += v.weight;
    if (bucket < cumulative) return v.name;
  }
  return variants[variants.length - 1].name;
}
```
The hash is deterministic — same userId + experimentId always yields same bucket. No database lookup required. Salting by experimentId means the same user gets independent assignments per experiment.

### Server-Side Assignment (No Flash)
Assign variant in middleware or server component before HTML renders. Never assign on the client — the variant swap is visible (FOUC) and JavaScript can be disabled.

```ts
// Next.js middleware.ts
export function middleware(req: NextRequest) {
  const userId = req.cookies.get('uid')?.value ?? generateAnonymousId();
  const variant = assignVariant(userId, 'checkout-cta', variants);
  const res = NextResponse.next();
  res.headers.set('x-ab-variant', variant);  // pass to server component
  res.cookies.set('uid', userId, { maxAge: 60 * 60 * 24 * 365 });
  return res;
}
```

### Track Exposure Before Conversion
```ts
// On page render (or at point variant is visible to user):
analytics.track('experiment_exposed', { experiment_id, variant, user_id, timestamp });

// On conversion:
analytics.track('checkout_completed', { experiment_id, variant, user_id, revenue });
```
Exposure event is the denominator. If you only track conversions, you cannot compute conversion rate. Never count conversions from users who were never exposed.

### Minimum Sample Size
Use a power calculator before starting:
- Significance level: α = 0.05
- Power: 1 − β = 0.80
- Minimum detectable effect: e.g., +2% absolute conversion rate
- Typical result: ~5,000 users per variant for a baseline conversion of 5%

```ts
// Rough formula for two-proportion z-test sample size per variant:
function sampleSize(baseRate: number, mde: number, alpha = 0.05, power = 0.8) {
  const p1 = baseRate;
  const p2 = baseRate + mde;
  const pBar = (p1 + p2) / 2;
  const zAlpha = 1.96;  // two-tailed, α=0.05
  const zBeta = 0.842;  // power=0.80
  return Math.ceil(
    ((zAlpha + zBeta) ** 2 * (p1 * (1 - p1) + p2 * (1 - p2))) / (p1 - p2) ** 2
  );
}
```

### When to Stop the Test
- Run until planned sample size is reached — not before.
- Check significance only at the planned end date (or use sequential testing with α-spending if you must peek).
- Declare a winner only if p-value < 0.05 and the effect direction is consistent across segments.
- If no significant difference after 2× the planned duration, declare a null result.

## Key Rules
- Assignment must be deterministic — same user, same variant every visit.
- Assign server-side to prevent flash of unstyled content.
- Log the exposure event at the moment the variant becomes visible — not at page load.
- Compute required sample size before starting; do not stop early.
- Never re-run a test after peeking and seeing a promising signal — that inflates false positives.
- Segment results post-hoc (device, channel) to detect heterogeneous effects, but pre-specify primary metric.
- Run only one major change per test — multiple changes make it impossible to attribute the effect.
