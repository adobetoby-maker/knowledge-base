# Domain Events as First-Class Objects

A domain event records that something meaningful happened in the business domain. Not a technical event (a button click, a database row update) — a business fact: `OrderPlaced`, `PaymentFailed`, `UserSubscribed`. Treating these as first-class objects, rather than side effects buried in service methods, changes what your system can do and how reliably it can do it.

## Naming: Past Tense, Business Language

Domain events are named in the past tense because they record facts that have already occurred. `OrderPlaced`, not `PlaceOrder`. `PaymentFailed`, not `PaymentFailure` or `FailedPayment`. The past tense is not a stylistic preference — it encodes the semantic distinction between a command (request to do something) and an event (record that something happened).

Use business language, not technical language. `UserRegistered` not `UserInserted`. `SubscriptionCancelled` not `SubscriptionStatusUpdatedToInactive`. The name should be recognizable to a domain expert who doesn't know the codebase.

## Payload Design: Self-Describing and Standalone

An event payload should contain enough context to be useful without fetching additional data. A consumer receiving `OrderPlaced` should not need to turn around and call an order service to find out what was ordered.

Include in every event:
- **Event type** — `"OrderPlaced"`
- **Event ID** — unique, for deduplication
- **Occurred at** — timestamp of when the fact became true, not when the event was published
- **Aggregate ID** — the ID of the entity this event is about
- **Relevant snapshot** — not the entire entity, but the fields that matter for this event

Avoid embedding objects that change frequently and whose change would make the event misleading. An event payload is a historical record — what was true at the moment of occurrence.

## Event Sourcing vs Event-Driven Architecture

These are related but distinct patterns, often confused:

**Event-driven architecture** uses events for communication between modules. `OrderService` publishes `OrderPlaced`; `InventoryService` and `NotificationService` subscribe and react. The events are a communication mechanism. The system of record is still a relational database storing current state.

**Event sourcing** uses events as the system of record itself. The current state of an aggregate is not stored directly — it is derived by replaying the event log. `Order` state is computed by applying `OrderPlaced → ItemAdded → ItemRemoved → PaymentCaptured` in sequence. This enables full audit history and temporal queries, but adds significant complexity: event schema migrations, eventual consistency in read models, replay performance.

Don't reach for event sourcing unless you have a genuine need for the full event history as source of truth (audit, time-travel debugging, complex event replay logic). Event-driven architecture, which is simpler, is the right default for decoupling modules.

## Synchronous vs Async Dispatch

**Synchronous dispatch** (in-process, same transaction): the event is dispatched and handled before the database transaction commits. Handlers run in the same request. Simple but couples the performance of all handlers to the originating operation, and any handler failure can roll back the entire transaction.

**Async dispatch** (outbox pattern, message broker): the event is written to an outbox table in the same transaction as the state change, then delivered to consumers asynchronously. This guarantees at-least-once delivery and decouples handler latency from the originating request. The tradeoff: consumers may see the event after a delay, and handlers must be idempotent (because at-least-once means they may receive the same event twice).

For side effects that must not fail silently (sending an email, charging a card, updating inventory), async with the outbox pattern is the correct choice. For in-process read model updates that are purely derived, synchronous is fine.

## Key Rules

- Name events in past tense using business language: `PaymentFailed`, not `PaymentStatusChanged`
- Event payloads must be self-describing — include enough context to act without a subsequent lookup
- Always include: event ID, event type, aggregate ID, occurred-at timestamp
- Event-driven (communication mechanism) and event sourcing (system of record) are different patterns — don't conflate them
- Synchronous dispatch is simple but couples handler failures to the originating transaction
- Async dispatch (outbox pattern) guarantees delivery but requires idempotent handlers
- Handlers receiving async events must tolerate duplicate delivery
