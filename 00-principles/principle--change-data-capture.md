# Principle: Change Data Capture (CDC)

## Overview
Change Data Capture reads the database transaction log and converts committed changes into an event stream. The fundamental advantage over application-layer event publishing is that CDC happens after the transaction commits — it's impossible to miss an event due to an application crash, network failure, or code bug. It eliminates the dual-write problem: the choice between "write to DB and hope the message broker call succeeds" vs "write to message broker and hope the DB write succeeds." With CDC, you only write to the DB; events are derived automatically.

## Implementation

### The Dual-Write Problem (Why CDC Exists)
```ts
// WRONG: Application emits event after DB write — can fail between the two
async function createOrder(data: OrderInput) {
  const order = await db.orders.create(data);
  // If this fails, the event is lost — downstream never knows the order was created
  await eventBus.publish('order.created', order);
  return order;
}

// CORRECT WITH OUTBOX: DB write includes event record atomically
async function createOrder(data: OrderInput) {
  return db.transaction(async (tx) => {
    const order = await tx.orders.create(data);
    // This is part of the same transaction — guaranteed to commit together
    await tx.outbox.create({ type: 'order.created', payload: order });
    return order;
  });
}
// A separate process reads the outbox and publishes events
```

### Postgres WAL-Based CDC with Debezium
Debezium reads the Postgres Write-Ahead Log (WAL) and emits events to Kafka:

```yaml
# Debezium Postgres connector config
{
  "name": "postgres-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.dbname": "myapp",
    "database.user": "debezium",
    "database.password": "${DEBEZIUM_PASSWORD}",
    "plugin.name": "pgoutput",
    "table.include.list": "public.orders,public.users,public.invoices",
    "topic.prefix": "myapp",
    "slot.name": "debezium_slot"
  }
}
```

```sql
-- Required Postgres setup for CDC
ALTER SYSTEM SET wal_level = logical;
-- Restart required after wal_level change

-- Create a replication slot for Debezium
SELECT pg_create_logical_replication_slot('debezium_slot', 'pgoutput');

-- Grant permissions
CREATE USER debezium REPLICATION LOGIN PASSWORD 'xxx';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium;
```

### Simpler: Outbox Pattern (Without Debezium)
For teams not running Kafka, the transactional outbox achieves CDC benefits at smaller scale:

```sql
CREATE TABLE outbox (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  payload    JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  published  BOOLEAN NOT NULL DEFAULT false,
  published_at TIMESTAMPTZ
);
```

```ts
// Transaction: DB write + outbox entry atomically
async function createUser(data: UserInput) {
  return db.transaction(async (tx) => {
    const user = await tx.query(`INSERT INTO users ... RETURNING *`);
    await tx.query(`
      INSERT INTO outbox (event_type, payload)
      VALUES ('user.created', $1)
    `, [JSON.stringify(user.rows[0])]);
    return user.rows[0];
  });
}

// Outbox poller (cron every 5 seconds)
async function pollOutbox() {
  const pending = await db.query(`
    SELECT * FROM outbox
    WHERE published = false
    ORDER BY created_at
    LIMIT 100
    FOR UPDATE SKIP LOCKED  -- prevents two workers from grabbing same rows
  `);

  for (const event of pending.rows) {
    try {
      await eventBus.publish(event.event_type, event.payload);
      await db.query(
        'UPDATE outbox SET published = true, published_at = now() WHERE id = $1',
        [event.id]
      );
    } catch (err) {
      // Leave unpublished; will retry on next poll
      console.error(`Failed to publish event ${event.id}:`, err);
    }
  }
}
```

### Event Schema (from CDC)
A CDC event contains:
- `before`: the row state before the change (null for INSERT)
- `after`: the row state after the change (null for DELETE)
- `op`: the operation type (`c` = create, `u` = update, `d` = delete, `r` = read/snapshot)
- `ts_ms`: the timestamp of the change at the source
- `source.lsn`: the WAL log sequence number (guaranteed ordering)

```ts
interface CDCEvent {
  before: Record<string, unknown> | null;
  after: Record<string, unknown> | null;
  op: 'c' | 'u' | 'd' | 'r';
  ts_ms: number;
  source: {
    table: string;
    db: string;
    lsn: number;
    txId: number;
  };
}
```

## Key Rules
- CDC events are emitted AFTER the transaction commits — they are reliable, not speculative.
- The WAL provides strict ordering via Log Sequence Number (LSN) — consumer ordering is guaranteed per-partition.
- The outbox pattern is CDC-lite: same atomicity guarantees for teams without Kafka or Debezium infrastructure.
- `FOR UPDATE SKIP LOCKED` in the outbox poller prevents duplicate processing by multiple workers.
- Debezium requires `wal_level = logical` in Postgres — set this before deployment; it requires a restart.
- Replication slots accumulate WAL until the consumer reads them — a dead consumer causes disk exhaustion; monitor slot lag.
- CDC consumers must be idempotent — network retries or reprocessing after failure should not corrupt downstream state.
