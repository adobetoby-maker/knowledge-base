# Principle: Command-Query Separation

## Overview
A function that both changes state and returns data is dangerous: calling it twice for logging, retrying on network failure, or reading it in two places produces unexpected mutations. Command-Query Separation (CQS) states that every function should be either a command (changes state, returns nothing or just an ID) or a query (reads state, has no side effects) — never both. This principle is the foundation of CQRS patterns and makes code safe to call in any context.

## The Fundamental Problem with Mixed Functions

```typescript
// Mixed: saves AND returns — calling twice saves twice
async function createAndGetUser(data: CreateUserData): Promise<User> {
  const user = await db.users.create(data);
  return user;
}

// Caller A: normal usage
const user = await createAndGetUser(data);

// Caller B: accidentally calls twice (retry logic, StrictMode double-invoke, etc.)
const user = await createAndGetUser(data);  // creates a SECOND user
const user = await createAndGetUser(data);  // AND A THIRD
```

The danger: the function looks like a query (it returns data) but is actually a command (it mutates). A caller that treats it like a query and calls it multiple times causes unintended mutations.

## Correct Separation

```typescript
// Command: mutates state, returns only what's needed to follow up
async function createUser(data: CreateUserData): Promise<{ id: string }> {
  const { id } = await db.users.create(data);
  return { id };
}

// Query: reads state, no side effects — safe to call N times
async function getUserById(id: string): Promise<User | null> {
  return db.users.findUnique({ where: { id } });
}

// Usage: explicit, safe to retry the query without re-running the command
const { id } = await createUser(data);
const user = await getUserById(id);
```

## Why Commands Return Only IDs (Not Full Objects)

Returning the full created object from a command couples the write path to the read path. Problems:
1. The write returns a "snapshot" that may be immediately stale (triggers, calculated fields)
2. Forces the write path to join related tables, adding query complexity
3. The caller may not need the full object — they just need to know it succeeded

Returning only the `id` lets the caller decide whether to fetch the full object via a separate query.

## Application to HTTP Endpoints

```typescript
// Command endpoint: POST (mutates, returns 201 + resource ID)
POST /orders
→ 201 Created
→ { "id": "ord_123" }

// Query endpoint: GET (reads, returns full resource)
GET /orders/ord_123
→ 200 OK
→ { "id": "ord_123", "status": "pending", "total": 4500, ... }
```

This is also why HTTP POST should not return the full created resource directly from the same DB operation — fetch it via a query after the write, or rely on the client to fetch it using the returned ID.

## Separate Read and Write Models (CQRS)

At scale, CQS naturally extends to using different data models for reads and writes:
- **Write model:** normalized, transaction-safe, enforces invariants
- **Read model:** denormalized, optimized for display, cached

This allows reads to scale independently of writes (read replicas, CDN-cached projections).

```typescript
// Write: creates order through normalized domain model
await orderRepository.create(order);

// Read: fetches denormalized view optimized for the orders list page
const orders = await orderReadModel.listByCustomer(customerId);
// This hits a pre-computed view or cache, not the normalized order table
```

## React / Frontend Application

CQS applies to UI too:
```typescript
// Bad: event handler both mutates AND drives navigation
function handleSubmit() {
  const result = await saveForm(data);  // command + query mixed
  router.push(`/orders/${result.id}`);  // using returned data
}

// Better: separate mutation from navigation
function handleSubmit() {
  const { id } = await createOrder(data);  // command returns only ID
  router.push(`/orders/${id}`);            // navigate; page fetches full data
}
```

## Key Rules
- A function is either a command (mutates, returns nothing or ID) or a query (reads, no side effects)
- Functions that do both are safe only if they are called exactly once — which you cannot guarantee
- Commands return the minimum needed to follow up (usually just an ID)
- Queries are safe to call multiple times, in any order, with no consequences
- This principle is especially important in systems with retry logic, React StrictMode, or queue consumers
- CQRS (at the architecture level) is CQS applied to entire data models and services
