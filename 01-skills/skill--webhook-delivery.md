# Skill: Reliable Webhook Delivery

## Purpose
Deliver outbound webhooks to customer endpoints with at-least-once guarantees, retry logic, and full observability. The hard part is not the happy path — it's handling slow, crashing, or misbehaving receivers without losing events or hammering them.

## Core Architecture

### Why At-Least-Once (Not Exactly-Once)
Exactly-once delivery is impossible across network boundaries. Accept that duplicates can happen and require receivers to be idempotent. Include a stable `event_id` (UUID) in every payload so receivers can deduplicate using their own `processed_events` table.

### Delivery Record in DB
Store every outbound webhook attempt before sending:
```sql
webhook_deliveries (
  id uuid primary key,
  endpoint_id uuid,       -- the customer's registered URL
  event_type text,
  payload jsonb,
  attempt_count int default 0,
  next_retry_at timestamptz,
  status text,            -- pending | delivered | failed | dead
  last_response_code int,
  last_error text,
  created_at timestamptz
)
```
Write the record first, then enqueue. If the process dies after writing but before enqueueing, a recovery job can re-enqueue anything `pending` older than N minutes.

### Retry Schedule — Exponential Backoff
Five attempts total, delays from first failure:
- Attempt 1: 1 minute
- Attempt 2: 5 minutes
- Attempt 3: 30 minutes
- Attempt 4: 2 hours
- Attempt 5: 8 hours

After attempt 5, set status = `dead` and enqueue to a **dead letter queue** (DLQ). Notify the customer via email/dashboard that their endpoint is failing. Keep DLQ records for 30 days — customers can replay them.

Only retry on 5xx responses and network timeouts. A 400 or 422 means the payload is wrong — retrying won't help, so dead-letter immediately and alert.

### Signature Verification — HMAC-SHA256
Sign every delivery. The receiver verifies before processing:
```
X-Webhook-Signature: sha256=<hex>
X-Webhook-Timestamp: 1716000000
```
Signature input: `timestamp + "." + raw_body_string`. Include timestamp to prevent replay attacks — reject signatures where `|now - timestamp| > 300s`. Customers store their signing secret (stored hashed server-side, shown plaintext once at creation).

### Timeout and Concurrency
Set a hard 10-second HTTP timeout per attempt. Receivers must respond with 2xx quickly — they should enqueue their own processing. Run deliveries in a background job worker (BullMQ, Inngest, etc.) so slow receivers don't block the queue. Cap per-endpoint concurrency to 3 to avoid overwhelming a single customer's server.

## Dashboard Requirements
Every delivery must be visible:
- Status per delivery: pending, delivered, failed, dead
- Full request/response bodies for debugging
- Manual retry button for dead-letter events
- Endpoint health score (success rate last 24h)
- Pause/disable endpoint automatically after prolonged failures (configurable threshold: e.g., >50% failure rate over 1h)

## Endpoint Registration
Customers register URLs via API or dashboard. Validate on registration: send a test ping with `{ "type": "ping" }` and expect 200. Store endpoint as inactive until verified.

## Key Rules
- **Write the delivery record before sending** — never fire-and-forget
- **Retry on 5xx and timeouts only** — dead-letter on 4xx immediately
- **Always verify HMAC on the receiver side** — reject without it
- **Include `event_id` in every payload** — idempotency is the receiver's responsibility
- **Enforce 10s timeout** — receivers that hang will exhaust worker threads
- **Dead-letter after 5 attempts** — alert the customer, keep records for replay
- **Cap per-endpoint concurrency** — a slow endpoint should not starve others
