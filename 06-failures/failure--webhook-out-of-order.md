# Failure: Webhook Out-of-Order Delivery

## Overview
Webhooks are delivered over unreliable networks. A provider may retry a failed delivery, deliver events in bursts after a network interruption, or process multiple events in parallel and deliver them in a different order than they occurred. An application that processes webhooks as if they arrive in sequence will apply stale updates, partially process retried events, or apply a "deleted" state before the "created" state. Robust webhook handlers are idempotent, order-tolerant, and treat each event as a snapshot of state rather than an instruction.

## The Out-of-Order Problem

```
Events generated on provider side (in order):
1. order.created     { id: "o1", status: "pending" }
2. order.updated     { id: "o1", status: "confirmed" }
3. order.updated     { id: "o1", status: "shipped" }

Events received by your server (out of order, due to retries):
3. order.updated     status: "shipped"    → sets status to "shipped"
1. order.created     status: "pending"    → overwrites to "pending"  ← WRONG
2. order.updated     status: "confirmed"  → overwrites to "confirmed" ← WRONG
Final state: "confirmed" instead of "shipped"
```

## Solution 1: Use `updated_at` to Skip Stale Events

If the provider includes an `updated_at` timestamp in the payload:
```typescript
async function handleOrderUpdate(event: WebhookEvent) {
  const { id, status, updated_at } = event.data;

  const existing = await db.orders.findById(id);

  // Skip if this event is older than what we already have
  if (existing && new Date(existing.updatedAt) >= new Date(updated_at)) {
    console.log(`Skipping stale event for order ${id}: ${updated_at} <= ${existing.updatedAt}`);
    return;
  }

  await db.orders.update({ id }, { status, updatedAt: updated_at });
}
```

This is the simplest and most reliable approach when timestamps are available.

## Solution 2: Sequence Numbers

If the provider provides a monotonic sequence number per resource:
```typescript
async function handleEvent(event: WebhookEvent) {
  const { resourceId, sequence, data } = event;

  const result = await db.raw(`
    UPDATE resources
    SET data = $2, last_sequence = $3
    WHERE id = $1 AND last_sequence < $3
  `, [resourceId, data, sequence]);

  if (result.rowCount === 0) {
    // Either resource doesn't exist or this was a stale event
    // Check which and handle accordingly
  }
}
```

The `WHERE last_sequence < $3` clause is a single atomic update that ignores stale events.

## Solution 3: Re-Fetch Current State on Every Event

Instead of trusting the event payload, fetch current state from the provider API on each event:
```typescript
async function handleOrderEvent(event: WebhookEvent) {
  // Don't trust the payload — always fetch fresh state
  const currentOrder = await stripeClient.orders.retrieve(event.data.object.id);

  await db.orders.upsert({
    where: { stripeId: currentOrder.id },
    update: { status: mapStatus(currentOrder.status) },
    create: { stripeId: currentOrder.id, status: mapStatus(currentOrder.status) },
  });
}
```

Trade-off: adds a provider API call per webhook, but eliminates all ordering concerns. Used by Stripe's official examples.

## Idempotency: Handling Retried Events

A webhook that was delivered but the acknowledgment (HTTP 200) was lost will be retried. Your handler must produce the same outcome if called multiple times:

```typescript
async function handlePaymentSucceeded(event: StripeEvent) {
  // Idempotency key: the event ID from the provider
  const existing = await db.processedEvents.findById(event.id);
  if (existing) {
    console.log(`Event ${event.id} already processed — skipping`);
    return;  // Idempotent: safe to return 200 again
  }

  // Process the event
  await db.orders.update({ stripePaymentId: event.data.object.id }, { status: 'paid' });
  await emailService.sendReceipt(event.data.object);

  // Record that this event was processed
  await db.processedEvents.create({ id: event.id, processedAt: new Date() });
}
```

Store `event.id` (from the provider) as a deduplication key. Most providers guarantee globally unique event IDs.

## Always Return 200 Quickly

Providers retry if they don't receive a timely 200. Long-running handlers should acknowledge immediately and process asynchronously:

```typescript
export async function POST(req: Request) {
  const payload = await req.text();

  // Verify signature before any processing
  verifyWebhookSignature(payload, req.headers.get('stripe-signature')!);

  // Enqueue for async processing — respond immediately
  await queue.push({ payload });

  return Response.json({ received: true });  // 200 immediately
  // Queue consumer handles the actual processing
}
```

## Key Rules
- Never assume webhooks arrive in chronological order — they don't
- Use `updated_at` comparison or sequence numbers to skip stale events
- Store processed event IDs to ensure idempotency across retries
- Return HTTP 200 within 5–10 seconds — use a queue for longer processing
- For payment providers (Stripe), re-fetching the resource is often simpler than trusting event order
- Verify the webhook signature before any processing — don't trust the payload origin
