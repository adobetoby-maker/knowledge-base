# Stripe Webhook Duplicate Events

Stripe delivers webhooks with an at-least-once guarantee, not exactly-once. Under certain conditions — your server timeouts, network hiccups, Stripe's own retry logic — the same event is delivered multiple times. Webhook handlers that aren't idempotent will process the event multiple times: charging a customer twice, creating two orders, sending duplicate confirmation emails.

## Why Stripe Retries

Stripe retries a webhook when:
- Your endpoint returns a non-2xx status code
- Your endpoint takes longer than 30 seconds to respond (Stripe's timeout)
- Network errors prevent delivery

The retry schedule is exponential, up to 3 days. This means a legitimate event that your server processed successfully but acknowledged too slowly (due to a slow database write) will be retried — and your handler will receive it again.

The important implication: your handler might succeed, but Stripe doesn't know that. A timeout is indistinguishable from a failure from Stripe's perspective.

## Idempotency via event.id

Every Stripe event has a unique `id` (e.g., `evt_1ABC...`). This is your idempotency key.

Before processing an event, check whether you've already processed that `event.id`:

```ts
const existing = await db.webhookEvents.findUnique({ where: { stripeEventId: event.id } });
if (existing) {
  return new Response("Already processed", { status: 200 });
}
```

After processing successfully:

```ts
await db.webhookEvents.create({ data: { stripeEventId: event.id, processedAt: new Date() } });
```

Important: this check-then-write is not atomic. If two deliveries of the same event arrive simultaneously (rare but possible under load), both could pass the check. Use a database unique constraint on `stripeEventId` to make the insert fail on the second attempt, and catch that specific error.

## Idempotent Order Fulfillment

The check against `event.id` handles replay at the handler level. But individual operations within the handler should also be idempotent where possible:

- **Creating an order**: use `payment_intent.id` or `checkout_session.id` as the order's idempotency key in your database, with a UNIQUE constraint
- **Sending an email**: check whether the email was already sent for this order before sending
- **Provisioning access**: use UPSERT (insert if not exists) rather than INSERT — hitting a duplicate is a no-op, not an error

Design the fulfillment steps so that running them twice produces the same result as running them once.

## Acknowledge Fast, Process Async

Stripe's 30-second timeout is the root cause of many replay storms. If your handler does slow work (database writes, third-party calls, email sending), you risk timing out and triggering a retry.

Pattern: acknowledge immediately, process async.

```ts
// 1. Verify signature
// 2. Write the raw event to a queue table
// 3. Return 200 immediately
// 4. A background worker processes the queue
```

The background worker owns idempotency. The webhook handler just records receipt. This keeps the webhook endpoint fast and prevents Stripe from ever timing out.

## Verifying the Signature

Always verify the Stripe webhook signature before processing. Stripe provides a signature in `Stripe-Signature` header. Use `stripe.webhooks.constructEvent()` — don't skip this step.

An unverified webhook handler can be triggered by anyone who can POST to your endpoint, allowing them to fake `payment_succeeded` events for arbitrary amounts.

## Key Rules

- Stripe delivers at-least-once; design handlers to be idempotent
- Check `event.id` against a processed-events table before acting; return 200 immediately for duplicates
- Use a UNIQUE constraint on `stripeEventId` to handle simultaneous duplicate deliveries
- Make fulfillment steps idempotent (UPSERT, duplicate-check before send)
- Acknowledge the webhook within 30s or Stripe will retry; push slow work to a background queue
- Always verify the `Stripe-Signature` header — never process an unverified payload
