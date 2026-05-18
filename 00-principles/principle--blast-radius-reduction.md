# Principle: Blast Radius Reduction

## Overview
Blast radius is not about preventing failures — it is about limiting the scope of damage when failures occur. Systems fail. Code has bugs. The question is not "will something go wrong" but "when it goes wrong, how many users are affected, for how long?" Blast radius reduction is the discipline of designing deployments and systems so that failures start small and can be contained before they spread.

## Key Points

### Regional Rollouts
Deploy to a subset of regions before all regions:
1. Deploy to `us-west-2` (smallest traffic region)
2. Monitor error rates, latency, and business metrics for 15–30 minutes
3. If healthy, deploy to `us-east-1`
4. If healthy, deploy remaining regions

**Why:** A bug that crashes the service only affects the region where it was deployed first. Rolling back one region is far faster than explaining a global outage.

### Canary Deployments
Shift a small percentage of traffic to the new version:
```
v1.2.3 → 90% of traffic
v1.2.4 → 10% of traffic (canary)
```
- Watch the canary's error rate vs. the stable version's error rate
- If canary error rate is higher → rollback canary
- If canary is healthy → shift 50% → then 100%

Services like Kubernetes, Argo Rollouts, and Vercel do this automatically.

### Feature Flag Ramp
For features, not deployments:
```
1% → 10% → 50% → 100%
```
Ramp based on user percentage, not time. Evaluate at each step:
- Error rate change
- Latency change
- Conversion rate change (for revenue-affecting features)
- Support volume change

If any metric degrades: disable the flag immediately, investigate, fix, re-ramp.

### Circuit Breaker Pattern
When a dependency is failing, stop calling it — fail fast for all requests instead of queuing and timing out:
```ts
const breaker = new CircuitBreaker(stripeClient.charge, {
  errorThresholdPercentage: 50,
  resetTimeout: 30000, // ms before trying again
});

// Open circuit → all calls fail immediately (no timeout wait)
// Prevents: cascading failures where slow dependency starves thread pool
```

Circuit breaker states:
- **Closed:** Normal operation, requests pass through
- **Open:** Dependency is failing, requests fail immediately without hitting the dependency
- **Half-open:** Testing if dependency recovered, limited requests allowed through

### Dependency Isolation
Failures in non-critical dependencies should not take down core functionality:
```
Core: can the user place an order?    → must never fail
Secondary: can we send a confirmation email? → can fail gracefully
Analytics: did we record the event?   → can fail silently
```
Wrap non-critical calls in try/catch that logs but does not rethrow. Use queues (BullMQ, Inngest) for non-critical side effects — they retry independently.

### Blast Radius vs. Probability
Engineers often spend effort on low-blast-radius failures because they're more likely. This is backwards. The rare event with large blast radius (global outage) costs more than many small failures:

```
Cost of failure = Probability × Blast Radius × Recovery Time
```

Focus blast radius reduction on the high-impact scenarios, not just the high-probability ones.

## Key Rules
- Deploy to one region (or canary) before all regions — never deploy globally without a staged rollout first
- Feature flags must have gradual ramp logic; enable for 1% before 100%
- Every external dependency call (payment processor, email, SMS) must have a circuit breaker or timeout
- Non-critical side effects (analytics, notifications) must not block the critical path
- Rollback procedure must be tested and documented before deployment — not decided during an incident
- Monitor business metrics (not just technical metrics) during rollouts — a deployment can be technically healthy but conversions can be broken
- Blast radius is a design decision, not an accident
