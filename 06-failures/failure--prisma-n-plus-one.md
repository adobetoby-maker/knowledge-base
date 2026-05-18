# Failure: Prisma N+1 Queries

## Overview
The N+1 query problem occurs when fetching N records and then making an additional database query for each one. Fetching 100 orders and then querying each order's customer separately produces 101 queries. With Prisma, this is invisible unless you log queries — the code looks clean but generates catastrophic database load. N+1 is the most common performance problem in ORM-based code.

## How N+1 Happens in Prisma

```typescript
// WRONG: N+1
const orders = await prisma.order.findMany({ where: { status: "pending" } });
// ^ 1 query: SELECT * FROM orders WHERE status = 'pending'

const ordersWithCustomers = await Promise.all(
  orders.map(async (order) => {
    const customer = await prisma.customer.findUnique({
      where: { id: order.customerId },
    });
    // ^ N queries: SELECT * FROM customers WHERE id = ? (once per order)
    return { ...order, customer };
  })
);

// Result: 1 + N queries. With 500 orders → 501 queries, each with network round-trip
```

## The Fix: `include` in the Initial Query

```typescript
// RIGHT: 1 query with a JOIN
const orders = await prisma.order.findMany({
  where: { status: "pending" },
  include: {
    customer: true, // Prisma generates a LEFT JOIN
  },
});
// ^ 1 query: SELECT orders.*, customers.* FROM orders LEFT JOIN customers ...
// Result: orders with customer already populated
```

## Conditional `include`

```typescript
// Conditionally include based on query params
const orders = await prisma.order.findMany({
  where: { status },
  include: {
    customer: true,
    items: {
      include: {
        product: true, // nested include — also prevents N+1 in items
      },
    },
    // Only include shipments if requested
    shipments: includeShipments ? {
      orderBy: { createdAt: "desc" },
      take: 1,
    } : false,
  },
});
```

## `select` vs `include`

```typescript
// include: adds the relation to the full model
const order = await prisma.order.findUnique({
  where: { id },
  include: { customer: true }, // customer is Customer model with all fields
});

// select: choose specific fields (reduces data transfer)
const order = await prisma.order.findUnique({
  where: { id },
  select: {
    id: true,
    totalCents: true,
    customer: {
      select: { name: true, email: true }, // only name and email
    },
  },
});
// Use select when you don't need all fields — reduces query payload
```

## Detecting N+1 in Prisma

```typescript
// Enable query logging in development
const prisma = new PrismaClient({
  log: ["query", "info", "warn", "error"],
});

// Or using middleware to count queries per request
prisma.$use(async (params, next) => {
  const before = Date.now();
  const result = await next(params);
  const after = Date.now();
  console.log(`Query ${params.model}.${params.action} took ${after - before}ms`);
  return result;
});
```

In production, use query count alerting: if a single request generates > 10 queries, log a warning. If > 50, log an error.

## Many-to-Many Without N+1

```typescript
// Fetch posts with their tags (many-to-many)
const posts = await prisma.post.findMany({
  include: {
    tags: {
      include: {
        tag: { select: { name: true } },
      },
    },
  },
});

// Prisma generates:
// SELECT * FROM posts
// SELECT * FROM _PostToTag WHERE postId IN (...)
// SELECT * FROM tags WHERE id IN (...)
// 3 queries regardless of how many posts — uses batch loading
```

## DataLoader Pattern for GraphQL Resolvers

When using Prisma with GraphQL resolvers, `include` doesn't work because resolvers are called independently:

```typescript
// Wrong: each resolver calls prisma separately → N+1
const resolvers = {
  Order: {
    customer: (order) => prisma.customer.findUnique({ where: { id: order.customerId } }),
    // ← called N times, one per order
  },
};

// Right: DataLoader batches calls within a single request tick
import DataLoader from "dataloader";

const customerLoader = new DataLoader(async (ids: string[]) => {
  const customers = await prisma.customer.findMany({ where: { id: { in: ids } } });
  return ids.map(id => customers.find(c => c.id === id) ?? null);
});

const resolvers = {
  Order: {
    customer: (order) => customerLoader.load(order.customerId),
    // ← batched: all N calls within one tick become one query
  },
};
```

## Key Rules
- Never loop over results and query inside the loop — always use `include` or batch loading
- Enable `log: ["query"]` during development to count queries per request
- Every relation that is accessed in rendering should be in `include` at the initial query
- Use `select` to limit fields on large models — reduces network payload
- For GraphQL: use DataLoader, not `include` (which doesn't compose with resolver chains)
- Alert when a single request generates more than 20 queries
- Test with a realistic data set — N+1 is invisible with 3 records, catastrophic with 3000
