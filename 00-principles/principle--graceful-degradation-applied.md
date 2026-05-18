# Principle: Graceful Degradation in Practice

## Relationship to Graceful Degradation

`principle--graceful-degradation.md` covers the theory: feature tiers, wrapping third-party calls, and progressive enhancement. This file covers the operational side: what to do when a dependency actually goes down in production, how to prepare for it in advance, and how to communicate degradation to users without eroding trust.

## Mapping Dependencies to Degraded States Before They Fail

Do not decide what "degraded mode" looks like when a service is down at 2am. Do it at design time. For each external dependency, define:

1. What features depend on it
2. Which of those features are core vs. enhancement
3. What the degraded experience looks like when it is unavailable
4. What the recovery trigger is (service restored, circuit closes, manual flag flip)

Document this in a dependency map, not in a runbook that nobody reads. The dependency map is code — it lives next to the feature code it describes.

## Feature Flags as Kill Switches

Every non-critical external call should be behind a feature flag that can be turned off without a deployment:

```typescript
async function enrichUserProfile(userId: string): Promise<EnrichedProfile> {
  if (!featureFlag.isEnabled('enrichment_service')) {
    return getBaseProfile(userId)   // degraded: base profile only
  }
  try {
    const enriched = await enrichmentService.fetch(userId)
    return { ...getBaseProfile(userId), ...enriched }
  } catch {
    return getBaseProfile(userId)   // same degraded path
  }
}
```

The flag serves two purposes: emergency kill switch when the service is misbehaving, and gradual re-enable when it recovers. Turning off a kill switch is safer than redeploying under incident pressure.

## Read-Only Mode as Fallback

When a write dependency (database, payment processor, inventory service) is degraded, read-only mode often allows the application to continue serving the majority of user journeys:

```typescript
function isReadOnly(): boolean {
  return !writeService.isHealthy()
}

// In a checkout flow:
if (isReadOnly()) {
  return <MaintenanceBanner message="Purchasing is temporarily unavailable. Your cart is saved." />
}
```

Read-only mode is not the same as "service down." Users who are browsing can still browse. Users who are in the middle of a purchase see a clear message rather than an error. The experience is degraded but functional for most use cases.

Implement read-only mode as an explicit application state, not as individual try/catch blocks scattered throughout the code. One flag, one banner, one consistent behavior.

## Circuit Breaker Integration

A circuit breaker tracks failure rate for a dependency and stops calling it when failures exceed a threshold. This prevents a slow, failing service from degrading response times for all requests:

```
CLOSED (normal): all requests pass through
OPEN (failing): all requests short-circuit to fallback immediately
HALF-OPEN (recovering): trial requests allowed; if they succeed, close the circuit
```

The important operational detail: the fallback for an open circuit must be pre-written and tested before the circuit ever opens. A circuit breaker with no tested fallback is a crash on failure rather than degradation.

## Communicating Degradation to Users

Silence is the worst option. A user who gets a spinner for 30 seconds and then an error has a worse experience than one who immediately sees "Some features are temporarily unavailable."

Principles for degradation messaging:
- **Be specific about what is unavailable** — "Purchasing is temporarily unavailable" is better than "Something went wrong"
- **Tell the user what still works** — "You can still browse products and view your order history"
- **Avoid false ETAs** — do not say "back in 5 minutes" unless you have a real signal; say "we are working on it"
- **Do not blame the dependency** — users do not care that your payment processor is down; they care that they cannot check out

Surface degradation at the UI layer closest to the affected feature, not as a full-page maintenance mode unless the core function of the page is unavailable. A checkout page with a degraded upsell widget does not need a full-page banner.

## Testing Degraded Paths

Degraded code paths are almost never tested in development because the dependency is always available locally. They fail in production where they matter. Test them explicitly:

- Mock the dependency to return failures and verify the degraded UI renders correctly
- Run integration tests with the dependency's circuit breaker forced open
- Use feature flags in staging to simulate disabled services

A degraded path that has never been tested in CI will surprise you in production.

## Key Rules

- Map each external dependency to its degraded state at design time, not at incident time
- Feature flags are kill switches — every non-critical external call should be behind one
- Read-only mode is an explicit application state, not scattered try/catch blocks
- Circuit breakers are only useful if the fallback is pre-written and tested
- Degradation messaging must be specific, calm, and honest — never vague or apologetic
- Test degraded paths in CI; paths that are never tested will fail when they matter
- Silence is worse than a clear degradation message — always communicate what is unavailable
