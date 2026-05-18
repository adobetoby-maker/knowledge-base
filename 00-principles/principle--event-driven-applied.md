# principle--event-driven-applied.md

Event-driven architecture is often discussed at the distributed systems level (Kafka, SNS, EventBridge), but the same pattern appears at smaller scales in a Next.js application — in-process events, webhook delivery, and durable background jobs. Choosing the right level depends on whether the event consumers are in the same process, a different service, or need guaranteed delivery across restarts.

## In-Process Events: Node.js EventEmitter

When event producers and consumers are in the same server process and you don't need persistence or guaranteed delivery, `EventEmitter` provides decoupled pub/sub without any infrastructure:

```ts
// lib/events.ts — singleton event bus
import { EventEmitter } from 'events';
export const bus = new EventEmitter();

// Producer (e.g., in a Route Handler after a form submit):
bus.emit('order.created', { orderId, userId, total });

// Consumer (register on app startup, e.g., in instrumentation.ts):
bus.on('order.created', async ({ orderId, userId }) => {
  await sendOrderConfirmationEmail(userId, orderId);
});
```

This works well for fire-and-forget side effects that don't need to survive a server restart. The limitation: if the Next.js server restarts between event emission and handling, the event is lost. Also, in Vercel's serverless model, each request gets an isolated function instance — a singleton `EventEmitter` won't be shared across concurrent requests.

For serverless deployments, in-process events only work for side effects that complete within the same request. If the side effect needs to happen asynchronously after the response is sent, use a durable queue.

## Webhook Delivery to External Systems

Webhooks are HTTP callbacks. When something happens in your system, you POST to a URL the external system registered. Key implementation concerns:

**Signing**: Sign webhook payloads with HMAC-SHA256 using a shared secret so receivers can verify authenticity. Stripe, GitHub, and most services use this pattern:

```ts
const signature = crypto
  .createHmac('sha256', webhookSecret)
  .update(rawBody)
  .digest('hex');
```

**Retries**: External systems may be down when you try to deliver. Don't retry from the original request — use a background job with exponential backoff. Store delivery attempts and mark webhooks as delivered once the receiver returns 2xx.

**Idempotency**: Webhook receivers should be idempotent. Delivery-at-least-once means the same event may arrive twice. Include an event ID in the payload and deduplicate on the receiver side.

## Inngest/Trigger.dev for Durable Processing

When you need events to survive server restarts, fan out to multiple consumers, execute with retries, or run as long-running workflows (minutes or hours), in-process EventEmitter is wrong. Use Inngest or Trigger.dev — they provide durable event queues backed by their infrastructure with a developer experience designed for Next.js:

```ts
// Inngest function — runs as a serverless function, durably
export const processOrder = inngest.createFunction(
  { id: 'process-order' },
  { event: 'order.created' },
  async ({ event, step }) => {
    const receipt = await step.run('charge-card', () =>
      stripe.charge(event.data.paymentMethodId, event.data.total)
    );
    await step.run('send-email', () =>
      sendOrderEmail(event.data.userId, receipt.id)
    );
  }
);
```

Each `step.run` is checkpointed. If the function fails mid-way, it resumes from the last checkpoint on retry rather than re-running from the start. This makes multi-step workflows reliable without building retry infrastructure yourself.

**Use Inngest/Trigger.dev when**: the operation has multiple steps, takes more than a few seconds, must not duplicate on retry, or must fan out to multiple consumers. **Use in-process EventEmitter when**: same-process, same-request side effects that are acceptable to lose on restart. **Use direct function calls when**: the coupling is intentional and loose coupling would just add indirection.

## Key Rules

- In-process `EventEmitter` only works for synchronous-to-the-request side effects in serverless — across restarts or across instances, events are lost.
- Sign outbound webhooks with HMAC-SHA256; validate inbound webhook signatures before processing.
- Webhook receivers must be idempotent — deduplicate on event ID because at-least-once delivery is the norm.
- Use Inngest or Trigger.dev for multi-step durable workflows that need checkpointing and retry without re-running completed steps.
- Don't add event-driven indirection to calls that are inherently coupled — a direct function call is clearer when the producer always wants exactly that consumer to run.
