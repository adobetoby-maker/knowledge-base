# Skill: Event Sourcing Implementation

## What This Covers

Event sourcing as a persistence strategy: storing the full history of state changes as an immutable sequence of events instead of only the current state. Covers the event store schema, optimistic concurrency, snapshots for performance, and rebuilding projections.

## Why Event Sourcing (and When Not To)

The core value: the audit log is the database, not a separate side table. You can reconstruct any past state, replay events to rebuild derived views, and debug production issues by replaying the exact sequence of events that led to a bug.

Use event sourcing when:
- Audit history is a first-class requirement (financial transactions, medical records)
- You need to replay events to build new read models retroactively
- The domain has complex state machines where understanding "how we got here" matters

Avoid event sourcing for:
- CRUD-heavy domains where history is irrelevant (user profile updates, settings)
- Teams without experience with eventual consistency — projections add complexity
- Small apps where the overhead isn't justified

## Event Store Schema

```sql
CREATE TABLE event_store (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_id   UUID NOT NULL,        -- aggregate root ID (e.g., order_id)
  stream_type TEXT NOT NULL,        -- aggregate type (e.g., 'Order', 'Invoice')
  version     INTEGER NOT NULL,     -- monotonically increasing per stream
  event_type  TEXT NOT NULL,        -- e.g., 'OrderPlaced', 'ItemAdded', 'OrderShipped'
  payload     JSONB NOT NULL,       -- event data
  metadata    JSONB DEFAULT '{}',  -- user_id, correlation_id, IP, etc.
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  UNIQUE (stream_id, version)       -- enforces ordering and optimistic concurrency
);

CREATE INDEX ON event_store (stream_id, version);
CREATE INDEX ON event_store (stream_type, created_at);
```

The `UNIQUE (stream_id, version)` constraint is the concurrency guard — two concurrent writers trying to append version 5 will get a unique violation; only one wins.

## Optimistic Concurrency

When appending an event, include the expected current version. If another process already wrote that version, the DB rejects the insert.

```ts
async function appendEvent(
  streamId: string,
  streamType: string,
  expectedVersion: number,
  eventType: string,
  payload: Record<string, unknown>,
  metadata: Record<string, unknown> = {}
) {
  const newVersion = expectedVersion + 1
  
  try {
    await db.query(
      `INSERT INTO event_store (stream_id, stream_type, version, event_type, payload, metadata)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [streamId, streamType, newVersion, eventType, payload, metadata]
    )
  } catch (err) {
    if (err.code === '23505') {  // unique_violation
      throw new ConcurrencyError(`Stream ${streamId} was modified concurrently`)
    }
    throw err
  }
}
```

Callers catch `ConcurrencyError` and retry by re-loading the stream and re-applying their command. This is optimistic locking — no pessimistic row locks needed.

## Loading and Applying Events

```ts
async function loadAggregate<T>(streamId: string, applyFn: (state: T, event: Event) => T, initial: T): Promise<{ state: T; version: number }> {
  const events = await db.query(
    `SELECT * FROM event_store WHERE stream_id = $1 ORDER BY version ASC`,
    [streamId]
  )
  
  let state = initial
  let version = 0
  
  for (const event of events.rows) {
    state = applyFn(state, event)
    version = event.version
  }
  
  return { state, version }
}
```

## Snapshots for Performance

Loading 10,000 events to reconstruct current state is slow. Snapshots cache the aggregate state at a given version so only events after the snapshot need replaying.

```sql
CREATE TABLE event_snapshots (
  stream_id   UUID PRIMARY KEY,
  version     INTEGER NOT NULL,
  state       JSONB NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

```ts
async function loadWithSnapshot<T>(streamId: string, applyFn: (state: T, event: Event) => T, initial: T) {
  const snapshot = await db.query(
    `SELECT * FROM event_snapshots WHERE stream_id = $1`,
    [streamId]
  )
  
  const fromVersion = snapshot.rows[0]?.version ?? 0
  const baseState = snapshot.rows[0] ? JSON.parse(snapshot.rows[0].state) : initial
  
  const events = await db.query(
    `SELECT * FROM event_store WHERE stream_id = $1 AND version > $2 ORDER BY version ASC`,
    [streamId, fromVersion]
  )
  
  // Only take a new snapshot when we've replayed many events since the last one
  if (events.rows.length > 50) {
    await saveSnapshot(streamId, newVersion, newState)
  }
  
  return reduce(events.rows, baseState, applyFn)
}
```

Take snapshots after every N events (50–200 is typical). Do not snapshot on every event — that negates the benefit and doubles write load.

## Projections

Projections are read models rebuilt from the event stream. They are the query side of CQRS. A projection listens to events and maintains a denormalized table optimized for reads.

```ts
// Rebuild a projection from scratch
async function rebuildOrderSummaryProjection() {
  await db.query(`TRUNCATE order_summaries`)
  
  const events = await db.query(
    `SELECT * FROM event_store WHERE stream_type = 'Order' ORDER BY created_at ASC`
  )
  
  for (const event of events.rows) {
    await applyToProjection(event)
  }
}

async function applyToProjection(event: Event) {
  switch (event.event_type) {
    case 'OrderPlaced':
      await db.query(`INSERT INTO order_summaries ...`)
      break
    case 'OrderShipped':
      await db.query(`UPDATE order_summaries SET status = 'shipped' WHERE id = $1`, [event.stream_id])
      break
  }
}
```

Projection rebuild is the killer feature: when requirements change, create a new projection table and replay all events to populate it. No data migration needed.

## Key Rules

- `UNIQUE (stream_id, version)` is non-negotiable — it is the concurrency mechanism
- Events are immutable once written — never update or delete event rows
- Store enough context in the payload to understand the event without querying other tables
- Snapshots are an optimization, not a requirement — add them when replay becomes slow
- Projections can always be rebuilt from scratch — do not treat them as authoritative
- Metadata (user_id, IP, correlation_id) goes in the metadata column, not payload
- Version 0 means no events yet; first event is always version 1
