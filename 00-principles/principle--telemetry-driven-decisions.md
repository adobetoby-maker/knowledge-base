# Principle: Telemetry-Driven Decisions

## Overview
Product and engineering decisions made without measurement are guesses dressed as decisions. Telemetry turns guesses into evidence: before optimization, you measure where time is spent; before a feature launch, you define what success looks like; after launch, you verify the metric moved. This is not about surveillance or dashboards for their own sake — it is about having the evidence to distinguish "this worked" from "we think this worked."

## Key Points

### Before Optimizing, Measure
The most common engineering mistake is optimizing the wrong thing:
```
"The page is slow" → engineer spends 3 days optimizing the DB query
→ Page is still slow → problem was actually a 1.2MB JavaScript bundle
```

Profile before optimizing:
- **Backend:** distributed tracing (OpenTelemetry) to see where request time is spent
- **Frontend:** Chrome DevTools / Lighthouse to identify render-blocking resources, LCP contributors
- **Database:** `EXPLAIN ANALYZE` to find slow queries, missing indexes, sequential scans

The goal of measurement before optimization is to spend engineering time on the actual bottleneck.

### Define Success Before Launch
Every feature launch needs a success metric defined before the feature ships:
```
Feature: New checkout flow redesign
Success metric: Checkout completion rate (orders / checkout starts) ≥ current baseline (68%)
Anti-metrics (should not degrade): Average order value, return visit rate within 7 days
Measurement period: 2 weeks after 100% rollout
Decision: If completion rate < 62%, rollback
```

Without this, post-launch analysis is subject to confirmation bias: teams find the metrics that look good and de-emphasize the ones that look bad.

### Instrumentation Is Not Optional
Instrumentation is a code requirement, not a nice-to-have:
```ts
// Track events at key user actions
analytics.track('checkout_started', {
  userId: user.id,
  cartValue: cart.total,
  itemCount: cart.items.length,
  source: params.source, // organic, email, paid
});

analytics.track('checkout_completed', {
  userId: user.id,
  orderId: order.id,
  revenue: order.total,
  paymentMethod: order.paymentMethod,
});

analytics.track('checkout_abandoned', {
  userId: user.id,
  step: 'payment', // where they left
  reason: error?.code,
});
```

Without these events, you cannot compute checkout completion rate, identify the abandonment step, or A/B test variants.

### The Measurement Loop
```
1. Hypothesis: "Adding social proof to the checkout page will increase completion rate"
2. Instrument: Add tracking for checkout_started, checkout_completed
3. Baseline: Measure current completion rate for 1 week
4. Ship: Deploy change to 10% of users via feature flag
5. Measure: Compare completion rate between control and treatment
6. Decide: If metric improved → ramp to 100%; if not → rollback, investigate
```

Skipping any step breaks the loop: no baseline means you cannot verify improvement; no treatment/control split means confounding variables contaminate the result.

### Error Rate Telemetry
```ts
// Log errors with context, not just message
logger.error('payment_failed', {
  userId: user.id,
  errorCode: error.code,
  paymentProvider: 'stripe',
  amount: charge.amount,
  traceId: ctx.traceId,
});
```

Alerts trigger when error rates exceed baselines — but baselines require historical data. Telemetry must be running before the incident, not instrumented in response to it.

### Telemetry Without Action Is Noise
Data collection is only valuable if it informs decisions:
- Dashboard that no one looks at = expensive write amplification on your analytics DB
- Metric with no alert threshold = unknown if it's degrading
- Event tracked but never queried = engineering time wasted

Audit instrumentation quarterly: what metrics drove an actual decision in the last 3 months? Prune what didn't.

## Key Rules
- Define the success metric before implementing the feature, not after it ships
- Profile first, optimize second — identify the actual bottleneck with data before writing any optimization code
- A/B test behavioral changes with proper statistical rigor (control/treatment, minimum sample size, confidence threshold)
- Every error path should emit structured telemetry, not just a generic log line
- Instrumentation code ships with the feature, not after it launches
- "I think users want X" is a hypothesis; measure it before building it at full scale
- Audit and prune unused telemetry — unmaintained dashboards and untriggered alerts erode trust in the system
