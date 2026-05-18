# Idempotency at Scale

Distributed systems deliver messages at-least-once. Networks timeout, retries fire, load balancers requeue. Design every mutation endpoint to be safe to call multiple times with the same intent — not just in theory, but under actual retry load.

## The Core Problem

At-most-once delivery is impossible to guarantee across process restarts. If a payment service crashes after charging the card but before writing the database record, the correct recovery is to retry — but retrying without idempotency double-charges the customer. The only safe assumption is: **any request may arrive more than once**.

## Idempotency Key Header

Accept an `Idempotency-Key` header (UUID v4, caller-generated) on all mutating endpoints. Return the same response for duplicate keys within the deduplication window. This is the client's way of saying "this is the same logical operation, not a new one."

```
POST /api/payments
Idempotency-Key: 7f3c2b1a-4e5d-6f7a-8b9c-0d1e2f3a4b5c
```

Store the key alongside the result in Redis with a TTL (24 hours is standard for payment flows; use shorter windows for lower-stakes operations). On receipt: check Redis first; if found, return cached response immediately without re-executing.

## Redis Deduplication Pattern

The deduplication store must be atomic. Use `SET key value NX EX ttl` — set only if not exists, with expiry. If the key already exists, return the stored response. If it doesn't exist, acquire the key optimistically (store a "processing" sentinel), execute the operation, then update with the final response.

Never check-then-set in two separate commands — that's a race condition. Two simultaneous retries could both miss the key and both execute.

## Side Effects That Can't Be Made Idempotent

Some actions are inherently non-idempotent: sending an email, publishing to a third-party webhook, posting to a social API. You cannot undo them, and the receiving system may not support deduplication keys.

For these, use **compensating transactions** instead of trying to prevent the second execution:
- Track what was sent in your own DB
- Detect the duplicate before hitting the external system
- If already sent, skip silently and return success
- If you find out post-hoc (email sent twice), compensate: send a correction, credit the account, log the anomaly

The outbox pattern (write event + DB record atomically, deliver separately) prevents most dual-delivery at the boundary.

## What Makes an Operation Truly Idempotent

An operation is idempotent when calling it N times produces the same state as calling it once. PUT is naturally idempotent; POST usually is not. Make POST idempotent through key-based deduplication. DELETE is idempotent if "already deleted" returns 200 or 404 consistently, not an error.

Database upserts (`INSERT ... ON CONFLICT DO UPDATE`) make writes idempotent at the storage layer. Prefer them over insert-then-check patterns when possible.

## Key Rules

- Require `Idempotency-Key` on all POST endpoints that create or charge anything
- Use Redis `SET NX EX` for atomic deduplication; never two-step check-then-set
- Set TTL based on your retry window — payment retries are often 24h, webhooks are shorter
- Assume at-least-once delivery as the default; never assume at-most-once
- For non-idempotent side effects (email, SMS, external webhooks), gate on a "sent" flag in your own DB before invoking
- Use compensating transactions when you can't prevent duplication, not error states
- Return the same status code and body for duplicate keys, not a "duplicate" error — the client should be unable to tell the difference
