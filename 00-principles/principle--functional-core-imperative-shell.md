# Principle: Functional Core, Imperative Shell

## Overview
Most bugs in application code live at the intersection of business logic and side effects. When a route handler simultaneously reads from the database, applies pricing rules, sends an email, and writes back — testing it requires a running database, a mock email server, and extraordinary setup. Separating pure logic (the core) from I/O (the shell) makes the logic trivially testable and the I/O thin and obvious.

## The Architecture

```
┌─────────────────────────────────────────────────────┐
│  Imperative Shell (thin)                             │
│  - HTTP handlers, cron jobs, queue consumers         │
│  - Reads input from outside world                    │
│  - Calls pure core functions                         │
│  - Writes output back to outside world               │
└──────────────────────┬──────────────────────────────┘
                       │ calls
┌──────────────────────▼──────────────────────────────┐
│  Functional Core (pure)                              │
│  - No DB access, no HTTP, no file I/O                │
│  - Takes data in, returns data out                   │
│  - Deterministic: same input → same output           │
│  - Testable with plain function calls                │
└─────────────────────────────────────────────────────┘
```

## Anti-Pattern: Logic in Shell

```typescript
// Business logic buried in a route handler — untestable without a running server
export async function POST(req: Request) {
  const { userId, items } = await req.json();
  const user = await db.users.findById(userId);               // I/O
  const discount = user.isVip ? 0.15 : 0;                    // logic mixed in
  const subtotal = items.reduce((s, i) => s + i.price, 0);   // logic mixed in
  const total = subtotal * (1 - discount);                    // logic mixed in
  await db.orders.create({ userId, total });                  // I/O
  await emailService.sendConfirmation(user.email, total);     // I/O
  return Response.json({ total });
}
```

Testing this requires a database, an email mock, and HTTP setup. If the discount logic is wrong, the error message comes from an HTTP assertion, not a clear unit test failure.

## Correct Pattern: Extract the Core

```typescript
// Pure core — no I/O, fully testable
export function calculateOrderTotal(
  items: OrderItem[],
  isVip: boolean
): { subtotal: number; discount: number; total: number } {
  const subtotal = items.reduce((s, i) => s + i.price, 0);
  const discount = isVip ? Math.floor(subtotal * 0.15) : 0;
  return { subtotal, discount, total: subtotal - discount };
}

// Thin shell — only I/O, no business logic
export async function POST(req: Request) {
  const { userId, items } = await req.json();
  const user = await db.users.findById(userId);               // I/O
  const result = calculateOrderTotal(items, user.isVip);      // pure call
  await db.orders.create({ userId, ...result });              // I/O
  await emailService.sendConfirmation(user.email, result.total); // I/O
  return Response.json(result);
}
```

Now `calculateOrderTotal` is tested with 20 unit tests. The route handler needs one integration test.

## What Belongs in the Core
- Pricing rules, discount calculations, tax logic
- State machine transitions ("can this order be cancelled given its current status?")
- Validation rules (not schema validation — business rule validation)
- Data transformations and mappings
- Date arithmetic and scheduling logic

## What Belongs in the Shell
- Database reads and writes
- HTTP requests to external APIs
- File system operations
- Queue sends and receives
- Email and notification sends

## The Rule of Thumb

If a function takes a database connection, an HTTP client, or a logger as an argument, it belongs in the shell. If it takes plain data and returns plain data, it belongs in the core.

## Key Rules
- Pure functions in the core: same input always produces same output, no side effects
- The shell reads from the outside world, calls the core, writes results back — in that order
- Never reach out to a database or external service from inside the core
- The core is the "business" of the application; the shell is the "plumbing"
- If you cannot test a function without mocking something, it has leaked I/O into the core
- Corollary: route handlers with business logic are a design flaw, not a shortcut
