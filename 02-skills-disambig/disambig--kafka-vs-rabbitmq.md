# Disambig: Kafka vs RabbitMQ

## Overview
Both are message brokers for decoupling services, but they use fundamentally different architectures. Kafka is a distributed log — messages are retained and consumers track their own position (offset). RabbitMQ is a traditional message queue — messages are deleted once acknowledged. This architectural difference determines which problems each solves well.

## Implementation / Key Points

### Kafka — Log-Based Messaging

```
Producer → Topic (partitioned log) → Consumer Group
                    ↓
            Messages retained (days/weeks)
            Multiple consumer groups read independently
            Each consumer tracks its own offset
```

```typescript
// Kafka producer
const producer = kafka.producer();
await producer.send({
  topic: 'order.created',
  messages: [{ key: orderId, value: JSON.stringify(order) }],
});

// Kafka consumer — offset-based
const consumer = kafka.consumer({ groupId: 'email-service' });
await consumer.subscribe({ topic: 'order.created' });
await consumer.run({
  eachMessage: async ({ message, offset }) => {
    await sendConfirmationEmail(JSON.parse(message.value.toString()));
  },
});
// A second consumer group (analytics-service) reads the same messages independently
// from its own offset — Kafka delivers to ALL consumer groups
```

**Kafka characteristics:**
- Messages persist after consumption (configurable retention period)
- Multiple consumer groups each receive all messages independently
- High throughput (millions of messages/second)
- Replay: rewind offset to reprocess historical messages
- Ordered within a partition (not globally)
- Consumer groups provide horizontal scaling within a group

### RabbitMQ — Queue-Based Messaging

```
Producer → Exchange → Queue → Consumer
                  ↓
            Message deleted after ACK
            One consumer (or competing consumers) per queue
            Flexible routing: direct, topic, fanout, headers
```

```typescript
// RabbitMQ producer
const channel = await connection.createChannel();
await channel.assertExchange('orders', 'topic', { durable: true });
channel.publish('orders', 'order.created', Buffer.from(JSON.stringify(order)));

// RabbitMQ consumer
channel.consume('email-queue', async (msg) => {
  await sendConfirmationEmail(JSON.parse(msg.content.toString()));
  channel.ack(msg);   // message deleted from queue after ack
  // channel.nack(msg) → message goes to dead letter queue
});

// For fan-out (multiple consumers each get the message):
// Fanout exchange → multiple queues → multiple consumers
```

**RabbitMQ characteristics:**
- Messages deleted on acknowledgment
- Flexible routing (direct/topic/fanout/headers exchange types)
- Dead letter queues for failed messages
- Message TTL (time-to-live) per message or queue
- Push-based delivery (broker pushes to consumers)
- Per-message priority queues

### Comparison
| Factor | Kafka | RabbitMQ |
|---|---|---|
| Message retention | Days/weeks (configurable) | Until acknowledged |
| Multiple consumers | All consumer groups get all messages | Competing consumers share queue (unless fanout) |
| Replay | Yes (rewind offset) | No |
| Throughput | Very high (millions/s) | High (tens of thousands/s) |
| Routing | By topic (partition key) | Flexible (exchange patterns) |
| Message ordering | Within partition | Single queue (FIFO) |
| Dead letters | Manually (DLT topics) | Built-in DLQ |
| Operational complexity | Higher | Lower |

### Use Case Mapping
| Use Case | Choose |
|---|---|
| Event sourcing / audit log | Kafka |
| Analytics pipeline | Kafka |
| High-volume event streaming | Kafka |
| Replay / reprocess past events | Kafka |
| Task queue (process jobs) | RabbitMQ |
| Work distribution across workers | RabbitMQ |
| Complex routing (some consumers get some messages) | RabbitMQ |
| Message TTL / expiry | RabbitMQ |
| Small team / simpler ops | RabbitMQ |

## Key Rules
- Use Kafka when multiple services need to independently consume the same events — Kafka delivers to all consumer groups
- Use RabbitMQ for task queues where each task is processed by exactly one worker
- Kafka's replay capability is uniquely valuable for event sourcing and debugging — no equivalent in RabbitMQ
- Don't use Kafka for simple task distribution — RabbitMQ's competing consumers pattern is simpler
- RabbitMQ's dead letter queues are a first-class feature; Kafka requires explicit DLT topic setup
- Kafka operational complexity is significant — managed services (Confluent, Upstash Kafka) reduce the burden
- Both support at-least-once delivery; exactly-once requires additional design work in either system
