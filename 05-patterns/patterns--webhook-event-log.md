# Pattern: Webhook Event Log

## Overview
Webhook delivery is unreliable — endpoints go down, timeouts happen, payloads get malformed. Without a visible event log, debugging integration failures requires grepping server logs or guessing. A structured log with retry UI lets both operators and developers diagnose and recover from failures without contacting support.

## Implementation

### Data Model
```sql
CREATE TABLE webhook_deliveries (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type  TEXT NOT NULL,           -- 'payment.succeeded', 'user.created'
  payload     JSONB NOT NULL,
  endpoint_url TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'pending', -- pending, delivered, failed
  http_status INT,
  response_body TEXT,
  attempt_count INT NOT NULL DEFAULT 0,
  next_retry_at TIMESTAMPTZ,
  delivered_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### Log List UI
```tsx
function WebhookEventLog() {
  const [filter, setFilter] = useState({ type: '', status: '' });
  const { data, fetchNextPage } = useInfiniteWebhookEvents(filter);

  return (
    <div>
      <FilterBar
        types={['payment.succeeded', 'user.created', 'subscription.cancelled']}
        statuses={['delivered', 'failed', 'pending']}
        value={filter}
        onChange={setFilter}
      />
      <table>
        <thead>
          <tr>
            <th>Event Type</th>
            <th>Status</th>
            <th>Attempts</th>
            <th>Timestamp</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {data.events.map(event => (
            <WebhookEventRow key={event.id} event={event} />
          ))}
        </tbody>
      </table>
      <button onClick={fetchNextPage}>Load more</button>
    </div>
  );
}

function WebhookEventRow({ event }) {
  const [expanded, setExpanded] = useState(false);

  return (
    <>
      <tr>
        <td><code>{event.eventType}</code></td>
        <td><StatusBadge status={event.status} /></td>
        <td>
          {event.attemptCount}
          {event.status === 'failed' && event.nextRetryAt && (
            <span className="text-muted"> · retry at {formatTime(event.nextRetryAt)}</span>
          )}
        </td>
        <td title={event.createdAt.toISOString()}>{formatRelative(event.createdAt)}</td>
        <td>
          <button onClick={() => setExpanded(!expanded)}>
            {expanded ? 'Hide' : 'Show'} payload
          </button>
          {event.status === 'failed' && (
            <button onClick={() => retryWebhook(event.id)}>Retry</button>
          )}
        </td>
      </tr>
      {expanded && (
        <tr>
          <td colSpan={5}>
            <pre>{JSON.stringify(event.payload, null, 2)}</pre>
            {event.responseBody && (
              <details>
                <summary>Response ({event.httpStatus})</summary>
                <pre>{event.responseBody}</pre>
              </details>
            )}
          </td>
        </tr>
      )}
    </>
  );
}
```

### Retry Handler
```typescript
async function retryWebhook(deliveryId: string) {
  const delivery = await db.webhookDeliveries.findById(deliveryId);
  if (delivery.status === 'delivered') return; // idempotency guard

  const result = await fetch(delivery.endpointUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Retry': 'true' },
    body: JSON.stringify(delivery.payload),
    signal: AbortSignal.timeout(10_000),
  });

  await db.webhookDeliveries.update({ id: deliveryId }, {
    status: result.ok ? 'delivered' : 'failed',
    httpStatus: result.status,
    responseBody: await result.text().catch(() => null),
    attemptCount: delivery.attemptCount + 1,
    deliveredAt: result.ok ? new Date() : null,
    nextRetryAt: result.ok ? null : calculateNextRetry(delivery.attemptCount + 1),
  });
}

// Exponential backoff: 5m, 30m, 2h, 8h, 24h
function calculateNextRetry(attemptCount: number): Date {
  const delays = [5, 30, 120, 480, 1440]; // minutes
  const delay = delays[Math.min(attemptCount - 1, delays.length - 1)];
  return new Date(Date.now() + delay * 60 * 1000);
}
```

## Key Rules
- Store full payload in the log — not just a reference — so you can retry without the original source
- Track HTTP status code and response body for every attempt, not just success/failure
- Show attempt count and next retry time on failed events
- Payload display must be collapsible — default collapsed to avoid overwhelming the UI
- Filter by event type and status — these are the two primary debugging axes
- Pagination via infinite scroll, not numbered pages — log is append-only and grows continuously
- Manual retry button for failed events — operators need this for debugging without re-triggering the original action
- Mark events as delivered atomically to prevent double-delivery on retry
- Keep logs for at least 30 days; consider 90 days for compliance-sensitive integrations
- The log is read-only — no editing payloads, no deleting entries
