# Disambig: tRPC vs REST vs GraphQL

## Overview
All three are patterns for client-server communication. REST is the established standard, language-agnostic, and cacheable. GraphQL provides flexible queries from a single endpoint and suits complex data graphs. tRPC provides end-to-end TypeScript type safety with zero schema files — but only works in TypeScript monorepos where client and server share code. The right choice depends on whether you have a polyglot system, public consumers, or a TypeScript-only full-stack.

## Implementation / Key Points

### tRPC — TypeScript RPC
```typescript
// server/router.ts
const ordersRouter = router({
  list: publicProcedure
    .input(z.object({ status: z.enum(['pending', 'shipped']).optional() }))
    .query(async ({ input }) => {
      return db.select().from(orders).where(
        input.status ? eq(orders.status, input.status) : undefined
      );
    }),
  
  create: protectedProcedure
    .input(z.object({ items: z.array(orderItemSchema) }))
    .mutation(async ({ input, ctx }) => {
      return db.insert(orders).values({ userId: ctx.userId, ...input });
    }),
});

// client/OrderList.tsx — types inferred automatically
const { data } = trpc.orders.list.useQuery({ status: 'pending' });
// data is typed as the return type of the query — no separate type file needed
```

**When to use tRPC:**
- TypeScript monorepo with shared types (Next.js full-stack, TurboRepo)
- Internal API consumed only by your own TypeScript frontend
- Want end-to-end type safety without writing schema files
- Team is TypeScript-first

**Limitations:**
- Client must be TypeScript (no mobile native clients, no Python scripts)
- No client-side HTTP caching (tRPC uses POST by default for queries)
- Not suitable for public APIs

### REST — Standard HTTP API
```typescript
// Handler
app.get('/api/orders', async (req, res) => {
  const { status } = req.query;
  const orders = await db.select().from(ordersTable)
    .where(status ? eq(ordersTable.status, status as string) : undefined);
  res.json(orders);
});

// Client — any language, any tool
const response = await fetch('/api/orders?status=pending');
const orders = await response.json();

# Python
import requests
orders = requests.get('/api/orders', params={'status': 'pending'}).json()
```

**When to use REST:**
- Public API consumed by third parties
- Multiple client types (web, mobile, Python scripts, other services)
- Need HTTP caching (GET requests cache at CDN/browser level)
- OpenAPI/Swagger documentation for clients

### GraphQL — Flexible Query API
```graphql
# Schema
type Query {
  orders(status: OrderStatus): [Order!]!
}

type Order {
  id: ID!
  status: OrderStatus!
  customer: Customer!
  items: [OrderItem!]!
}
```
```typescript
// Client query
const { data } = useQuery(gql`
  query Orders($status: OrderStatus) {
    orders(status: $status) {
      id
      status
      customer { name }
      items { quantity product { name price } }
    }
  }
`, { variables: { status: 'PENDING' } });
// Client gets exactly what it asked for — no more, no less
```

**When to use GraphQL:**
- Multiple clients with different data needs (mobile vs web vs analytics)
- Complex related data (loading a dashboard with many entity types)
- Rapid iteration on frontend data requirements without API changes
- Organization already invested in GraphQL tooling

**GraphQL risks:**
- N+1 queries if resolvers aren't written with DataLoader
- Complexity overhead for simple CRUD
- Requires schema management tooling

### Decision Matrix
| Factor | tRPC | REST | GraphQL |
|---|---|---|---|
| Type safety | Automatic (TypeScript only) | Manual or code-gen | Schema + code-gen |
| Public consumers | No | Yes | Yes |
| Multiple languages | No | Yes | Yes |
| HTTP caching | Limited | Native | Requires persisted queries |
| Complex data graphs | No | Verbose | Excellent |
| Setup complexity | Low | Low | High |
| Bundle size | ~30KB | 0KB | ~50-150KB |

## Key Rules
- Use tRPC for TypeScript-only monorepos — it eliminates the entire type-sync problem
- Use REST for public APIs, third-party consumers, or polyglot teams
- Use GraphQL when multiple clients have genuinely different data shape requirements
- Don't use GraphQL for simple CRUD — the complexity overhead isn't justified
- tRPC and REST can coexist — use tRPC for internal routes, REST for public webhooks/APIs
- REST + Zod input validation + TypeScript return types approximates tRPC's type safety with more work
