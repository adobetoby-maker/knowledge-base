# Principle: Transactional Outbox Pattern

## The Dual-Write Problem

When a service saves data to a database and then publishes an event to a message broker (Kafka, SQS, RabbitMQ), it performs two separate writes. These two writes are not atomic. The process can crash between them. The database write commits but the event never gets published. Downstream services never learn the order was placed. The system is now silently inconsistent.

The dual-write problem is not solved by retrying the publish — you can't know if the crash happened before or after the publish succeeded. Retrying blindly causes duplicate events.

## How the Outbox Solves It

Instead of writing to the broker directly, write the event to an `outbox` table in the **same database transaction** as the main data change. One transaction, one commit, atomically consistent.

```sql
BEGIN;
  INSERT INTO orders (id, customer_id, total) VALUES ($1, $2, $3);
  INSERT INTO outbox (id, aggregate_type, aggregate_id, event_type, payload, created_at)
  VALUES ($4, 'order', $1, 'OrderPlaced', $5, NOW());
COMMIT;
```

A separate **relay process** reads unpublished outbox rows and publishes them to the broker, then marks them published. The relay can crash and restart safely — it will just re-read and re-publish unprocessed rows.

## Polling Relay vs CDC with Debezium

**Polling relay** — a background job queries `WHERE published_at IS NULL ORDER BY created_at LIMIT 100` on an interval. Simple to implement, works everywhere. The downside: polling adds latency (you wait for the next poll interval) and creates load on the database at scale.

**Change Data Capture (CDC) with Debezium** — reads the database's binary replication log and streams every committed change to Kafka topics in near real-time. No polling, no extra database load, sub-second latency. The downside: Debezium requires infrastructure (Kafka Connect), and it only works with databases that expose a WAL (Postgres, MySQL). For most apps, start with polling; graduate to CDC when volume demands it.

## At-Least-Once Delivery

The relay guarantees at-least-once delivery, not exactly-once. If the relay publishes an event and then crashes before marking it published, it will publish the same event again on restart. Consumers must be **idempotent** — processing the same event twice must produce the same outcome as processing it once.

Design idempotency into every consumer:

```typescript
// Use event ID as an idempotency key
async function handleOrderPlaced(event: OutboxEvent) {
  const alreadyProcessed = await db.query(
    "SELECT 1 FROM processed_events WHERE event_id = $1",
    [event.id]
  );
  if (alreadyProcessed.rowCount > 0) return;

  await db.transaction(async (tx) => {
    await fulfillOrder(tx, event.payload);
    await tx.query("INSERT INTO processed_events (event_id) VALUES ($1)", [event.id]);
  });
}
```

## Outbox Schema

```sql
CREATE TABLE outbox (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  aggregate_type  TEXT NOT NULL,   -- 'order', 'user', etc.
  aggregate_id    TEXT NOT NULL,
  event_type      TEXT NOT NULL,   -- 'OrderPlaced', 'UserRegistered'
  payload         JSONB NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  published_at    TIMESTAMPTZ,     -- NULL = pending
  error           TEXT             -- last relay error, for debugging
);

CREATE INDEX idx_outbox_pending ON outbox (created_at) WHERE published_at IS NULL;
```

## Key Rules

- **Never write to broker directly from a business transaction** — use the outbox table instead.
- **Outbox insert must be in the same transaction as the domain change** — that's the whole point.
- **Relay publishes then marks, not marks then publishes** — if the relay crashes after publishing but before marking, re-publishing is safe; the reverse causes silent message loss.
- **All consumers must be idempotent** — at-least-once means duplicates will happen.
- **Index on `(created_at) WHERE published_at IS NULL`** — polling without this index will table-scan under load.
- **Start with polling relay** — Debezium is powerful but operationally heavy; earn it.
- **Archive or delete old outbox rows** — they accumulate fast and bloat the table.
