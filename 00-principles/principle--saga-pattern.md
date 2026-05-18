# Principle: Saga Pattern

## The Problem It Solves

Distributed systems can't use a single database transaction that spans multiple services. A traditional two-phase commit (2PC) locks resources across services simultaneously — this works on paper but creates tight coupling, blocks on coordinator failure, and doesn't scale. The saga pattern replaces atomicity with eventual consistency via a sequence of local transactions, each of which publishes an event or message that triggers the next step.

The tradeoff: you give up "all or nothing" in a single instant in exchange for a system that can actually run at scale and survive partial failures.

## Choreography vs Orchestration

**Choreography** — each service listens for events and decides what to do next. No central brain. Works well for simple flows with few steps. Fails badly as complexity grows: the flow becomes implicit and scattered, dead-letter queues pile up, and debugging "where did the saga go?" becomes a slog.

**Orchestration** — a dedicated saga orchestrator sends commands to services and waits for responses. The flow is explicit and lives in one place. Easier to reason about, easier to add rollback logic, easier to observe. Prefer this for anything involving money, orders, or multi-step workflows.

## Compensating Transactions Are the Core Idea

Each saga step must have a corresponding **compensating transaction** — the business-level undo. These are not SQL rollbacks. They are real business operations:

- "Reserve inventory" → compensate with "release inventory"
- "Charge payment" → compensate with "issue refund"
- "Send email confirmation" → compensate with "send cancellation email" (can't un-send, so compensate by sending another)

Compensating transactions must be **idempotent** — if the orchestrator retries them (network failure, crash-restart), running them twice must produce the same outcome as running them once. Use idempotency keys tied to the saga ID + step number.

## TypeScript Orchestration Example

```typescript
type SagaStep<Ctx> = {
  name: string;
  execute: (ctx: Ctx) => Promise<Ctx>;
  compensate: (ctx: Ctx) => Promise<void>;
};

async function runSaga<Ctx>(steps: SagaStep<Ctx>[], initialCtx: Ctx): Promise<Ctx> {
  const completed: SagaStep<Ctx>[] = [];
  let ctx = initialCtx;

  for (const step of steps) {
    try {
      ctx = await step.execute(ctx);
      completed.push(step);
    } catch (err) {
      // Rollback in reverse order
      for (const done of [...completed].reverse()) {
        await done.compensate(ctx).catch((e) =>
          console.error(`Compensation failed for ${done.name}:`, e)
        );
      }
      throw new Error(`Saga failed at step "${step.name}": ${err}`);
    }
  }

  return ctx;
}

// Usage
const orderSaga: SagaStep<OrderContext>[] = [
  {
    name: "reserve-inventory",
    execute: async (ctx) => ({ ...ctx, reservationId: await inventory.reserve(ctx.items) }),
    compensate: async (ctx) => inventory.release(ctx.reservationId),
  },
  {
    name: "charge-payment",
    execute: async (ctx) => ({ ...ctx, chargeId: await payments.charge(ctx.amount) }),
    compensate: async (ctx) => payments.refund(ctx.chargeId),
  },
  {
    name: "create-order",
    execute: async (ctx) => ({ ...ctx, orderId: await orders.create(ctx) }),
    compensate: async (ctx) => orders.cancel(ctx.orderId),
  },
];
```

## Failure Isolation

A saga step fails in isolation. The rest of the system keeps running. Compare to 2PC where a coordinator crash leaves all participants locked until recovery. With sagas, the worst case is a partially-completed flow that needs compensations — not a system-wide freeze.

Persist saga state to a database. If the orchestrator crashes mid-saga, it must be able to resume from the last completed step — not restart from scratch.

## Key Rules

- **Every step needs a compensating transaction** — design compensation before you design execution.
- **Compensations must be idempotent** — tie them to saga ID + step, not to timestamps.
- **Persist saga state durably** — in-memory sagas are lost on restart; use a `sagas` table.
- **Prefer orchestration over choreography** for flows with 3+ steps or any rollback logic.
- **Never use 2PC across services** — it's a distributed deadlock waiting to happen.
- **Log every step transition** — saga debugging without logs is archaeology.
- **Compensations can fail too** — handle compensation failures separately (alert, dead-letter, manual review).
