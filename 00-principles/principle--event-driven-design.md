# Principle: Event-Driven Design

## What It Is

Instead of chaining direct function calls for side effects, publish an event when something meaningful happens and let subscribers handle what to do next. The publisher doesn't know or care about the subscribers.

"An invoice was paid" → email receipt, update accounting, close the service ticket, send satisfaction survey. These are separate concerns triggered by one event.

## Why Direct Calls Break Down

```ts
// WRONG — direct coupling
async function markInvoicePaid(invoiceId: string) {
  await updateInvoiceStatus(invoiceId, 'paid')
  await sendReceiptEmail(invoiceId)        // What if email fails?
  await syncToQuickbooks(invoiceId)        // What if QB is down?
  await createFollowUpTask(invoiceId)      // Not related to paying
  await sendSatisfactionSurvey(invoiceId)  // Should this be instant?
}
```

Problems: if email fails, the transaction rolls back even though payment succeeded. Adding a new side effect requires modifying `markInvoicePaid`. Testing requires mocking all side effects.

## Simple Event Bus Pattern

```ts
// lib/events.ts
type EventHandler<T> = (payload: T) => Promise<void>

const handlers: Record<string, EventHandler<unknown>[]> = {}

export function on<T>(event: string, handler: EventHandler<T>) {
  handlers[event] = [...(handlers[event] ?? []), handler as EventHandler<unknown>]
}

export async function emit<T>(event: string, payload: T): Promise<void> {
  const eventHandlers = handlers[event] ?? []
  // Run all handlers, collect errors but don't let one block others
  const results = await Promise.allSettled(
    eventHandlers.map((handler) => handler(payload))
  )
  
  results.forEach((result, i) => {
    if (result.status === 'rejected') {
      console.error(`Handler ${i} for event "${event}" failed:`, result.reason)
    }
  })
}

// Register handlers at app startup
import './events/invoiceHandlers'
import './events/notificationHandlers'
```

```ts
// events/invoiceHandlers.ts
import { on } from '@/lib/events'

on('invoice.paid', async ({ invoiceId }: { invoiceId: string }) => {
  await sendReceiptEmail(invoiceId)
})

on('invoice.paid', async ({ invoiceId }: { invoiceId: string }) => {
  await syncToQuickbooks(invoiceId).catch((err) => {
    // QB sync is best-effort — log and continue
    console.error('QB sync failed:', err)
  })
})
```

```ts
// The publisher — clean and simple
async function markInvoicePaid(invoiceId: string) {
  await updateInvoiceStatus(invoiceId, 'paid')
  await emit('invoice.paid', { invoiceId })
}
```

## Database-Backed Events (Durable)

For events that must not be lost (payments, signups), store them in the database before processing:

```sql
CREATE TABLE domain_events (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type        TEXT NOT NULL,
  payload     JSONB NOT NULL,
  processed   BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT now(),
  processed_at TIMESTAMPTZ
);
```

```ts
async function publishEvent(type: string, payload: object): Promise<void> {
  await supabase.from('domain_events').insert({ type, payload })
  // Background job processes pending events
}

// Processor (runs on cron)
async function processEvents() {
  const { data: events } = await supabase
    .from('domain_events')
    .select('*')
    .eq('processed', false)
    .order('created_at')
    .limit(50)

  for (const event of events ?? []) {
    try {
      await emit(event.type, event.payload)
      await supabase.from('domain_events')
        .update({ processed: true, processed_at: new Date().toISOString() })
        .eq('id', event.id)
    } catch (err) {
      console.error(`Failed to process event ${event.id}:`, err)
    }
  }
}
```

Durable events survive server crashes and process failures. The trade-off is latency — events aren't processed instantly.

## Webhook Delivery as Events

```ts
// When a payment webhook arrives from Stripe
await emit('stripe.payment_intent.succeeded', { paymentIntentId, amount, metadata })

// Handlers
on('stripe.payment_intent.succeeded', async (payload) => {
  const orderId = payload.metadata.orderId
  await markOrderPaid(orderId)
})

on('stripe.payment_intent.succeeded', async (payload) => {
  await sendOrderConfirmation(payload.metadata.orderId)
})
```

Webhook events are naturally suited to event-driven processing — they're already fire-and-forget from Stripe's perspective.

## When NOT to Use Events

Don't over-engineer with events for:
- Simple request/response (user clicks "save" → save the record)
- Operations that must be transactional (can't split across handlers)
- Cases where the caller needs the result from the side effect

Events are for side effects that are separate concerns from the main action. The main action should still return synchronously. Side effects are by definition not required for the response.
