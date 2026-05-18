# Principle: Event Sourcing

## Overview

Event sourcing stores every state change as an immutable event rather than the current state. The current state is derived by replaying events. Full audit history is free, temporal queries are trivial, and debugging becomes "replay to point-in-time". The cost is complexity — CQRS (separate read/write models) is almost always needed alongside it.

## When to Use

**Good fit:**
- Financial systems (every cent needs a paper trail)
- Complex domain logic with many state transitions (order fulfillment, insurance claims)
- Audit requirements (healthcare, finance, legal)
- Need to reconstruct state at any point in time

**Probably overkill:**
- CRUD apps with simple data flows
- Most SaaS features
- Anything a soft-delete + audit log would handle adequately

## Event Store Schema

```sql
CREATE TABLE events (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_id      TEXT NOT NULL,          -- Entity ID (e.g., 'order:123')
  stream_type    TEXT NOT NULL,          -- 'order', 'account', 'user'
  event_type     TEXT NOT NULL,          -- 'OrderPlaced', 'OrderShipped', 'OrderCancelled'
  sequence_number BIGINT NOT NULL,       -- Position within stream
  payload        JSONB NOT NULL,
  metadata       JSONB NOT NULL DEFAULT '{}',  -- causation_id, user_id, ip
  occurred_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Prevent duplicate events at same sequence position
CREATE UNIQUE INDEX events_stream_sequence ON events(stream_id, sequence_number);
CREATE INDEX events_stream_occurred ON events(stream_id, occurred_at);
CREATE INDEX events_type ON events(event_type, occurred_at DESC);
```

## Appending Events (Optimistic Concurrency)

```ts
async function appendEvent(
  streamId: string,
  streamType: string,
  eventType: string,
  payload: object,
  expectedSequence: number  // Current highest sequence — prevents lost update
): Promise<void> {
  const nextSequence = expectedSequence + 1

  try {
    await db.insert(events).values({
      streamId,
      streamType,
      eventType,
      sequenceNumber: nextSequence,
      payload: JSON.stringify(payload),
    })
  } catch (err) {
    // Unique constraint violation = concurrent write
    if (isUniqueConstraintError(err)) {
      throw new ConcurrencyError(`Stream ${streamId} was modified concurrently`)
    }
    throw err
  }
}
```

## Aggregate Reconstruction

```ts
interface OrderState {
  id: string
  status: 'pending' | 'confirmed' | 'shipped' | 'delivered' | 'cancelled'
  items: OrderItem[]
  totalCents: number
  shippingAddress: Address | null
}

type OrderEvent =
  | { type: 'OrderPlaced'; orderId: string; items: OrderItem[]; totalCents: number }
  | { type: 'OrderConfirmed' }
  | { type: 'OrderShipped'; trackingNumber: string }
  | { type: 'OrderDelivered' }
  | { type: 'OrderCancelled'; reason: string }

function applyEvent(state: OrderState, event: OrderEvent): OrderState {
  switch (event.type) {
    case 'OrderPlaced':
      return { ...state, status: 'pending', items: event.items, totalCents: event.totalCents }
    case 'OrderConfirmed':
      return { ...state, status: 'confirmed' }
    case 'OrderShipped':
      return { ...state, status: 'shipped' }
    case 'OrderDelivered':
      return { ...state, status: 'delivered' }
    case 'OrderCancelled':
      return { ...state, status: 'cancelled' }
  }
}

async function rehydrateOrder(orderId: string): Promise<OrderState> {
  const storedEvents = await db.query.events.findMany({
    where: and(
      eq(events.streamId, `order:${orderId}`),
      eq(events.streamType, 'order'),
    ),
    orderBy: [asc(events.sequenceNumber)],
  })

  const initial: OrderState = {
    id: orderId,
    status: 'pending',
    items: [],
    totalCents: 0,
    shippingAddress: null,
  }

  return storedEvents.reduce(
    (state, e) => applyEvent(state, e.payload as OrderEvent),
    initial
  )
}
```

## Projections (Read Models)

Rebuild query-optimized views from the event stream:

```ts
// Run as a background job to keep read model in sync
async function rebuildOrderProjections(): Promise<void> {
  const lastProcessed = await getLastProcessedEventId()

  const newEvents = await db.query.events.findMany({
    where: and(
      eq(events.streamType, 'order'),
      gt(events.id, lastProcessed),
    ),
    orderBy: [asc(events.occurredAt)],
  })

  for (const event of newEvents) {
    await updateProjection(event)
    await setLastProcessedEventId(event.id)
  }
}

async function updateProjection(event: StoredEvent): Promise<void> {
  const payload = event.payload as OrderEvent
  const orderId = event.streamId.replace('order:', '')

  switch (payload.type) {
    case 'OrderPlaced':
      await db.insert(orderProjections).values({
        orderId,
        status: 'pending',
        totalCents: payload.totalCents,
        itemCount: payload.items.length,
      }).onConflictDoUpdate({
        target: orderProjections.orderId,
        set: { status: 'pending', totalCents: payload.totalCents },
      })
      break
    case 'OrderShipped':
      await db.update(orderProjections)
        .set({ status: 'shipped', trackingNumber: payload.trackingNumber })
        .where(eq(orderProjections.orderId, orderId))
      break
    // ...
  }
}
```

## Key Rules

- Events are past-tense facts: `OrderPlaced` not `PlaceOrder`. They describe what happened, not commands.
- Never mutate events — they are the source of truth. Add compensating events to correct mistakes.
- `sequence_number` per stream enables optimistic concurrency — prevents lost updates without locks.
- CQRS is almost required: write by appending events, read from projections — trying to query the event log directly is slow.
- Snapshots reduce replay time for high-event streams: store current state every 100 events, replay only newer ones.
