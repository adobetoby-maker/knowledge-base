# Principle: Testing in Production

## Overview
Staging parity with production is never perfect. Staging has different traffic patterns, different data distributions, different third-party API states, and often fewer resources. The only way to know how a system behaves in production is to observe it in production. "Testing in production" is not recklessness — it is a disciplined set of techniques that validate real production behavior while limiting the blast radius of failures.

## Technique 1: Feature Flags for Gradual Rollout

Deploy code to 100% of instances, but expose the feature to a percentage of users:

```typescript
// Check feature flag before executing new code path
const enabled = await featureFlags.isEnabled("new-checkout-flow", {
  userId: user.id,
  rolloutPercentage: 5, // 5% of users see the new flow
});

if (enabled) {
  return newCheckoutFlow(cart);
} else {
  return legacyCheckoutFlow(cart);
}
```

Rollout sequence: 0.1% → 1% → 5% → 25% → 50% → 100%, with monitoring between each step. If error rate spikes at 5%, roll back by setting percentage back to 0 — no code deploy required.

## Technique 2: Synthetic Monitoring

Automated scripts that run real user flows against production endpoints on a schedule:

```typescript
// Synthetics run every 5 minutes from multiple regions
// They simulate real user actions, not just HTTP pings
describe("checkout flow synthetic", () => {
  it("completes a purchase end-to-end", async () => {
    const session = await login(SYNTHETIC_USER_EMAIL, SYNTHETIC_USER_PASSWORD);
    const cart = await addToCart(session, SYNTHETIC_PRODUCT_ID, 1);
    const order = await checkout(session, cart.id, SYNTHETIC_PAYMENT_METHOD);
    expect(order.status).toBe("confirmed");
    await cancelOrder(session, order.id); // cleanup
  });
});
```

Synthetic failures fire alerts before real users notice. Tools: Datadog Synthetics, Checkly, Playwright Cloud.

## Technique 3: Canary Deployments

Route a small percentage of real traffic to the new version before full rollout:

```
Load Balancer:
  90% traffic → v1.2.0 (stable)
  10% traffic → v1.3.0 (canary)

Monitor for 30 minutes:
  - Error rate on v1.3.0 vs v1.2.0
  - P99 latency on v1.3.0
  - Business metrics (conversion rate, order completion)

If metrics are healthy: promote canary to 100%
If metrics regress: route all traffic back to v1.2.0
```

Kubernetes: Argo Rollouts or Flagger automate this. Vercel: preview deployments with traffic splitting.

## Technique 4: Log-Based Anomaly Detection

New code paths produce new log patterns. Alert on unexpected error rates in production logs rather than waiting for user reports:

```typescript
// Log at key decision points with event names
logger.info("checkout.payment_attempted", { userId, orderId, provider });
logger.error("checkout.payment_failed", { userId, orderId, reason });

// Alerting rule (Datadog, CloudWatch, Loki):
// If error rate for "checkout.payment_failed" exceeds 2% of "checkout.payment_attempted"
// over a 5-minute window → alert
```

## Technique 5: Shadow Mode / Dark Launch

Run new code in parallel with old code, log the results, but only serve old code's response to users:

```typescript
async function getRecommendations(userId: string) {
  const [oldResult, newResult] = await Promise.allSettled([
    oldRecommendationEngine(userId),
    newRecommendationEngine(userId), // runs but result discarded
  ]);

  if (newResult.status === "fulfilled") {
    logger.info("shadow.recommendations.compared", {
      userId,
      oldCount: oldResult.value?.length,
      newCount: newResult.value.length,
      match: JSON.stringify(oldResult.value) === JSON.stringify(newResult.value),
    });
  }

  return oldResult.value; // always serve old result
}
```

Dark launch lets you validate correctness and performance of new code with real data before it affects real users.

## Staging Is Not Enough, But Still Valuable

Staging remains useful for: gross functional testing, smoke tests before promoting to production, integration tests with third-party sandboxes. The mistake is treating staging as sufficient for production validation. Always combine staging smoke tests with production observability.

## Key Rules
- Feature flags are the primary mechanism for gradual production validation
- Synthetic monitors run business-critical flows every 5 minutes
- Canary deployments for any change that affects performance or money
- Alert on error *rate* changes, not individual errors
- Dark launch for algorithmic changes (recommendations, ranking, pricing)
- Rollback = change a flag or route weight; never require a code deploy for rollback
- Every new feature ships with a dashboard widget showing its key metric from day one
