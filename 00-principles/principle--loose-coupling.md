# Loose Coupling

Coupling measures how much one module needs to know about the internals of another to function. Tight coupling is not a style problem — it's a structural constraint that limits how independently modules can change, test, and deploy.

## Why Tight Coupling Makes Testing Hard

A tightly coupled module requires its dependencies to be present and functioning to be tested. When `OrderService` directly instantiates `EmailService` and `PaymentGateway`, you cannot test order logic without standing up email infrastructure and a payment sandbox. Test setup time grows, tests become flaky (network-dependent), and the unit test boundary blurs into integration territory.

Loose coupling, particularly through interface-based injection, lets you substitute a fake `EmailService` in tests. The test verifies the order logic; it doesn't care about email delivery. This is not just a convenience — it's the mechanism by which you can test fast and test in isolation.

## Interface-Based Decoupling

Define interactions through contracts (interfaces, abstract types), not concrete implementations. The caller declares what it needs; the container or caller's caller decides what provides it.

```ts
interface Notifier {
  send(userId: string, message: string): Promise<void>
}

class OrderService {
  constructor(private notifier: Notifier) {}
}
```

`OrderService` doesn't know if `Notifier` is email, SMS, or a no-op test stub. When you switch from SendGrid to Postmark, `OrderService` doesn't change.

This is dependency injection at its simplest. The goal isn't the DI framework; it's the boundary.

## Event-Driven Decoupling

When two modules need to respond to each other's state changes but shouldn't share an interface, events are the right boundary. Instead of `OrderService` calling `InventoryService.decrementStock()` directly, `OrderService` emits `OrderPlaced`. `InventoryService` listens for `OrderPlaced` and handles stock.

The benefit: `OrderService` doesn't need to know that `InventoryService` exists. If tomorrow you add a `WarehouseNotificationService` that also cares about `OrderPlaced`, you wire it up without touching `OrderService`.

The cost: the flow of logic is no longer traceable by reading one file top-to-bottom. Debugging requires following the event chain. Introduce events deliberately where the decoupling benefit is real, not reflexively.

## The Cost of Over-Decoupling

Indirection hides bugs. When a system has five layers of interfaces, adapters, event buses, and message queues between a UI action and a database write, a bug anywhere in that chain is hard to trace. Stack traces stop at the event boundary. You need tooling (correlation IDs, distributed tracing) just to follow a single request.

Over-decoupled systems are also harder to reason about locally. "What happens when this button is clicked?" should have a traceable answer. If the answer is "it emits an event, which is picked up by a handler, which calls a service that emits another event..." for a simple CRUD operation, the architecture has overcomplicated the problem.

Apply coupling reduction where it solves a real problem: testability, independent deployability, avoiding circular dependencies. Don't apply it everywhere as a virtue.

## Circular Dependencies as a Coupling Red Flag

When module A depends on module B and module B depends on module A, you have a cycle. Cycles are a sign that the boundary between the two modules is wrong — they are not actually separate concerns. The fix is not to break the cycle with an event bus (that hides the problem); it's to restructure the modules so the shared concern is extracted into a third module that both depend on.

## Key Rules

- Tight coupling is a structural constraint, not a style issue — it limits testability and independent evolution
- Depend on interfaces (contracts), not concrete implementations, at module boundaries
- Use events when modules need to react to each other without explicit coupling, but not for simple sequential flows
- Over-decoupling hides bugs; add indirection only when the benefit (testability, deployability) is real
- Circular dependencies indicate wrong module boundaries — fix the structure, don't paper over it
- The test: can this module be tested without instantiating its neighbors? If no, you have coupling to address
