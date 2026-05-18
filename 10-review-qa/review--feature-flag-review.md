# Review: Feature Flag Review

## Overview
Feature flags decouple deployment from release, enabling dark launches, gradual rollouts, and instant rollbacks. The risk is that flags accumulate — flags without owners, flags with unclear default behavior, flags that have been "temporary" for two years. A feature flag review prevents the flag graveyard and ensures each flag is safe to evaluate in production.

## Implementation / Key Points

### Flag Lifecycle Metadata
Every feature flag must have:
```typescript
// Bad: anonymous flag with no context
const showNewCheckout = featureFlags.get('new_checkout');

// Good: documented flag with lifecycle metadata
// Feature flag: new-checkout-flow
// Owner: @platform-team
// Created: 2024-11-01
// Sunset date: 2025-02-01 (remove after full rollout)
// Default (if flag server down): false = old checkout (safe)
const showNewCheckout = featureFlags.get('new-checkout-flow', false);
```

### Default Value = Current Behavior (Not New Behavior)
```typescript
// Bad: default is the new feature — flag server outage enables unfinished feature
featureFlags.get('experimental-checkout', true);  // true = new feature

// Good: default is safe/current behavior — outage is invisible to users
featureFlags.get('experimental-checkout', false);  // false = current checkout
```
When the flag evaluation service is unavailable, the application should behave as it did before the flag existed.

### Kill Switch Defaults to On
For kill switches (flags that disable a feature on demand):
```typescript
// Kill switch pattern
// Flag meaning: "payment processing enabled" 
// Default: true = feature ON (current behavior)
// Set to false to disable instantly without deploy
const paymentsEnabled = featureFlags.get('payments-enabled', true);
```
A kill switch that defaults to `false` (off) means a flag server outage disables the feature. The default must preserve the pre-incident state.

### Evaluate Flags at Render, Not in Utilities
```typescript
// Bad: flag evaluated deep in utility function
function formatPrice(amount: number): string {
  if (featureFlags.get('new-currency-format')) {
    return newFormat(amount);
  }
  return oldFormat(amount);
}

// Good: flag evaluated at component/handler level, passed down
function CheckoutPage() {
  const useNewFormat = featureFlags.get('new-currency-format', false);
  return <PriceDisplay formatter={useNewFormat ? newFormat : oldFormat} />;
}
```
Flags in utility functions are invisible — hard to trace, test, and eventually remove. Evaluate at the boundary where behavior changes.

### No Flag Logic in Database Schema
```sql
-- Bad: flag referenced in database logic
CREATE VIEW active_products AS
SELECT * FROM products 
WHERE (feature_flag_enabled('new-catalog') OR status = 'active');
```
Database views and constraints cannot be toggled in production without a migration. Flag logic belongs in application code.

### Sunset Date Enforcement
```typescript
// In CI or startup, verify no expired flags exist
function checkFlagSunsets() {
  const expiredFlags = allFlags.filter(f => f.sunsetDate < new Date());
  if (expiredFlags.length > 0) {
    console.warn('Expired feature flags:', expiredFlags.map(f => f.key));
    // In strict mode: throw new Error(...)
  }
}
```
Flags past their sunset date should fail CI or emit a warning on startup. This prevents flags from persisting indefinitely.

### Feature Flag Review Checklist
- [ ] Flag has an owner (team or individual)
- [ ] Flag has a sunset date documented
- [ ] Default value preserves current behavior (not new behavior)
- [ ] Kill switches default to on (service continues without flag server)
- [ ] Flag evaluation is at component/route level, not in utility functions
- [ ] No flag logic in SQL views, triggers, or constraints
- [ ] Flag naming is clear: `feature-name-enabled` not `ff_v2_new_thing_123`
- [ ] Old flags (past sunset date) have removal tickets filed
- [ ] Flag is not duplicated across multiple keys with similar names

## Key Rules
- Default flag values must preserve existing behavior — never default to the new/experimental path
- Kill switches must default to enabled (on) — a flag server outage should not disable features
- Evaluate flags at the render or handler layer, not in utility or library functions
- Every flag needs an owner and a sunset date at creation — these are non-negotiable
- Flag logic doesn't belong in the database — views, triggers, and constraints can't be toggled without a migration
- Expired flags must be removed — accumulation of dead flag code is a maintenance and cognitive burden
