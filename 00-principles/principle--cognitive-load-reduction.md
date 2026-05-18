# Principle: Cognitive Load Reduction

## Overview
Working memory can hold roughly 4–7 items simultaneously. When a function, module, or system requires tracking more context than that to understand, comprehension fails — engineers slow down, make mistakes, and avoid touching the code. Reducing cognitive load is not about aesthetics; it is about the speed at which engineers can safely understand and modify code.

## Implementation / Key Points

### One Mental Model Per Module
A module that does two unrelated things requires two mental models to understand. If you need to hold both in your head to reason about either, the module should be split.

```ts
// High cognitive load: one module, two mental models
// UserAuthService.ts — handles auth AND user profile management AND subscription status

// Low cognitive load: three modules, one mental model each
// auth.ts         — authentication only
// profile.ts      — profile read/write only  
// subscription.ts — subscription state only
```

### Long Functions = Many Things to Hold Simultaneously
A 200-line function requires understanding 200 lines of context to know what any one line does. A 20-line function has a small enough context window that a human can understand it in full.

```ts
// Before: 80-line processOrder function
// After: orchestration function calling well-named helpers

async function processOrder(orderId: string) {
  const order = await fetchOrder(orderId);
  await validateInventory(order.items);
  const total = calculateOrderTotal(order);
  const charge = await chargePayment(order.customerId, total);
  await fulfillOrder(order, charge.id);
  await notifyCustomer(order.customerId, order);
}
```
Each helper has a single, named purpose. The orchestration function reads like a sentence.

### Deeply Nested Conditionals
Every level of nesting adds a state to track. Three-level nesting = 8 possible paths, all held simultaneously.

```ts
// Bad: track nested state
function getDiscount(user, order) {
  if (user.isPremium) {
    if (order.total > 100) {
      if (order.isFirstOrder) {
        return 0.20;
      }
      return 0.15;
    }
    return 0.10;
  }
  return 0;
}

// Good: early returns reduce nesting (one condition at a time)
function getDiscount(user, order) {
  if (!user.isPremium) return 0;
  if (order.total <= 100) return 0.10;
  if (order.isFirstOrder) return 0.20;
  return 0.15;
}
```

### Generic Variable Names Force Context-Switching
```ts
// Bad: requires jumping to definition to understand each variable
const data = await fetch(url);
const result = processData(data);
const item = result.items[0];

// Good: name reveals meaning without requiring context lookup
const rawApiResponse = await fetch(url);
const parsedMetrics = parseMetrics(rawApiResponse);
const topPerformer = parsedMetrics.items[0];
```

### The "Newspaper Test"
Read the function or module from top to bottom as if reading prose. If you need to pause, jump to a definition, or re-read a line, cognitive load is too high at that point. Mark those points and refactor.

### Comments That Add Cognitive Load
Comments that explain WHAT the code does are noise — the code already says what it does. Comments that explain WHY add signal.

```ts
// Bad (explains what — already visible)
// multiply quantity by unit price
const total = quantity * unitPrice;

// Good (explains why — not visible from code)
// Unit price is stored in cents to avoid floating point errors
const totalCents = quantity * unitPriceCents;
```

## Key Rules
- One mental model per module — split modules that require holding two models simultaneously.
- Functions longer than ~30 lines are candidates for decomposition — not automatically wrong, but scrutinize them.
- Nesting beyond 2 levels is a flag — use early returns, guard clauses, or extracted functions.
- Generic variable names (`data`, `result`, `item`, `temp`) require context-switching; rename them.
- Names should reveal intent without requiring the reader to trace to definitions.
- Comments explain WHY, not WHAT; WHAT-comments are maintenance debt.
- Each refactoring should leave less to remember, not more abstraction to track.
