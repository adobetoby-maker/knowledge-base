# Principle: Hexagonal Architecture (Ports and Adapters)

## The Core Idea

Domain logic should have no opinion about how it's invoked or where it persists data. HTTP, databases, message queues, and CLIs are all delivery mechanisms — they carry signals in and out, but they are not the application. Hexagonal architecture formalizes this by drawing a hard boundary between the domain and the outside world.

The boundary is expressed as **ports** (interfaces your domain defines) and **adapters** (concrete implementations that satisfy those interfaces). The domain owns the ports. The infrastructure layer owns the adapters.

## Primary vs Secondary Ports

**Primary (driving) ports** — how the outside world invokes the domain. A web controller calls a use-case function. A message consumer calls the same use-case function. The domain doesn't know which; both go through the same port.

**Secondary (driven) ports** — how the domain talks to infrastructure. A `UserRepository` interface defined in the domain layer. A Postgres implementation lives in the infrastructure layer and implements that interface.

The direction of dependency matters: infrastructure adapters depend on domain ports. The domain never imports from infrastructure. This is what makes testing trivially easy — swap the Postgres adapter with an in-memory adapter and your domain tests run in milliseconds with zero I/O.

## Why It Makes Testing Trivially Easy

Without this separation, a unit test for "charge a customer" has to stub HTTP calls, mock a database connection, and hope the ORM doesn't do something weird. With hexagonal architecture, the charge logic depends only on a `PaymentGateway` interface and an `OrderRepository` interface. Your test provides in-memory fakes. No network, no database, no flakiness.

This isn't just convenience — it forces you to design interfaces that are actually useful to the domain, not shaped by what the database happens to support.

## Structuring a Next.js App with Hexagonal Principles

```
src/
  domain/
    order/
      types.ts           # Pure types — no imports from outside domain
      orderService.ts    # Use cases — depends only on domain types + ports
      ports.ts           # Interfaces: OrderRepository, PaymentGateway
  infrastructure/
    db/
      supabaseOrderRepo.ts  # Implements OrderRepository using Supabase
    payments/
      stripeGateway.ts      # Implements PaymentGateway using Stripe SDK
  app/
    api/
      orders/
        route.ts          # HTTP adapter — calls orderService, translates HTTP↔domain
```

The `route.ts` file is an adapter. It translates an HTTP request into a call to `orderService.placeOrder(...)` and translates the domain result back into an HTTP response. It does not contain business logic.

## Avoiding Framework Bleeding Into Domain

Framework bleeding happens when domain logic starts importing from Next.js, Prisma, or any infrastructure library. Signs of bleeding:

- Domain functions returning `NextResponse` objects
- Domain types importing Prisma's generated types
- Use-case functions calling `headers()` or `cookies()` directly
- Domain logic checking `process.env.NODE_ENV`

When framework concepts leak in, your domain can only run inside that framework. You can't test it in isolation. You can't reuse it in a CLI script. You can't migrate to a different framework without rewriting business logic.

The fix is consistent: define what the domain needs as an interface, pass it in from outside.

```typescript
// BAD — domain imports infrastructure
import { prisma } from "@/lib/prisma";
export async function placeOrder(data: OrderData) {
  return prisma.order.create({ data });
}

// GOOD — domain depends on a port
export async function placeOrder(
  data: OrderData,
  repo: OrderRepository  // interface defined in domain
): Promise<Order> {
  // pure business logic here
}
```

## Key Rules

- **Domain never imports from infrastructure** — if `src/domain/` imports from `src/infrastructure/`, it's wrong.
- **Ports are interfaces owned by the domain** — not by the thing implementing them.
- **Adapters are thin** — translation only; no business logic.
- **Test domain logic against in-memory fakes** — never against real databases or HTTP.
- **One use case per function** — `placeOrder`, not `handleOrderStuff`.
- **Framework types stay in adapters** — `Request`, `Response`, ORM types never enter domain.
