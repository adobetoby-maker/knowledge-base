# Webhook Push vs Client Polling — When to Use Each

## The Fundamental Trade-off

Webhooks are server-initiated: the upstream service calls your endpoint the moment something happens. Polling is client-initiated: your code asks the upstream service "has anything changed?" on a schedule. The choice is not about preference — it is about who controls the event and whether you can afford the infrastructure to receive it.

## Webhook Strengths

**Latency.** A webhook fires within milliseconds of the triggering event. Polling at 60-second intervals means up to a 60-second delay. For time-sensitive flows (payment confirmed → provision service; deploy finished → notify team), webhooks are the only viable choice.

**Efficiency.** A webhook call happens once per event. Polling at 1-minute intervals makes 1,440 API calls per day even when nothing changes. At scale this exhausts rate limits and costs real money.

**Less code in your hot path.** Polling requires a cron job, a state-tracking mechanism (last-seen cursor or timestamp), and deduplication logic. Webhooks push the state management responsibility to the sender.

## Webhook Weaknesses

**You must be reachable.** Webhooks require a public HTTPS endpoint. This rules them out for local development (without ngrok/smee), IoT devices behind NAT, mobile clients, or any consumer application that cannot expose a server.

**Reliability shifts to you.** If your endpoint is down when the event fires, you must rely on the sender's retry policy (usually exponential backoff for 24–72 hours, then the event is lost). Design webhook handlers to be idempotent — the sender will retry on 5xx responses, so processing the same payload twice must be safe.

**Security surface.** Any public endpoint is a potential attack vector. Always verify the webhook signature (HMAC-SHA256 header) before processing the payload. Never trust the payload's claimed identity without this check.

## When Polling Is Actually Better

**High-volume streams where you control the pace.** If an upstream service emits thousands of events per minute and you only need to process them in batches, polling lets you pull at your own rate and apply backpressure. Webhooks would overwhelm your queue.

**Simple clients that cannot receive inbound traffic.** A cron job checking an email inbox, a script that checks a CI pipeline status, a mobile app checking for background updates — all of these are easier with polling.

**Eventual consistency is fine and the upstream has no webhook support.** Many APIs (legacy systems, third-party data vendors) only expose GET endpoints. Polling is the only option.

**Development and debugging.** Polling is trivially testable with `curl`. Webhooks require tunnels, mock payloads, and signature generation to test locally.

## Hybrid Pattern

Use webhooks to trigger invalidation and polling/fetch for the actual data. Webhook arrives → mark a record as dirty → background job fetches the fresh state. This decouples delivery guarantees from data freshness and avoids trusting potentially stale webhook payloads.

## Key Rules

- **Always verify webhook signatures** before touching the payload — reject unsigned requests with 401, not 500.
- **Return 200 immediately** from a webhook handler, then process asynchronously. Slow handlers cause retries that cause duplicate processing.
- **Make webhook handlers idempotent** using the event ID — store processed IDs and skip duplicates.
- When polling, use a **cursor or `updatedAt` filter** rather than fetching everything and diffing client-side — it does not scale.
- Never poll at intervals shorter than 5 seconds against third-party APIs — you will hit rate limits and get banned.
- If both options are available, prefer webhooks for event-driven flows and reserve polling for batch jobs and systems without inbound connectivity.
