# Pattern: Activity Timeline

## Overview
A resource activity timeline answers "what happened to this thing?" — critical for support, debugging, and accountability. Pagination breaks the mental model of a timeline; infinite scroll preserves it. Distinguishing automated system events from human actions prevents false accusations and helps diagnose whether a bug or a person caused a state change.

## Implementation

### Data Model
```sql
CREATE TABLE resource_activity (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_type TEXT NOT NULL,       -- 'invoice', 'order', 'user'
  resource_id   TEXT NOT NULL,
  actor_type    TEXT NOT NULL,       -- 'user' | 'system' | 'api'
  actor_id      TEXT,                -- user ID or service name
  actor_label   TEXT,                -- denormalized: email or service name
  action        TEXT NOT NULL,       -- 'created', 'updated', 'status_changed', 'commented'
  changes       JSONB,               -- { field: [before, after] }
  note          TEXT,                -- optional human-readable note
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ON resource_activity (resource_type, resource_id, created_at DESC);
```

### Fetching with Infinite Scroll
```typescript
// Cursor-based pagination — stable even as new events are inserted
async function getResourceActivity(
  resourceType: string,
  resourceId: string,
  cursor?: string,  // ISO timestamp of last event fetched
  limit = 25,
  actorFilter?: string
) {
  return db.resourceActivity.findMany({
    where: {
      resourceType,
      resourceId,
      actorLabel: actorFilter ? { contains: actorFilter } : undefined,
      createdAt: cursor ? { lt: new Date(cursor) } : undefined,
    },
    orderBy: { createdAt: 'desc' },
    take: limit + 1, // fetch one extra to know if there are more
  });
}
```

### Timeline Component
```tsx
function ActivityTimeline({ resourceType, resourceId }) {
  const [actorFilter, setActorFilter] = useState('');
  const { data, fetchNextPage, hasNextPage } = useInfiniteQuery({
    queryKey: ['activity', resourceType, resourceId, actorFilter],
    queryFn: ({ pageParam }) => getResourceActivity(resourceType, resourceId, pageParam, 25, actorFilter),
    getNextPageParam: (lastPage) => {
      if (lastPage.length < 25) return undefined;
      return lastPage[lastPage.length - 1].createdAt.toISOString();
    },
  });

  const events = data?.pages.flat() ?? [];
  const grouped = groupByDay(events); // { 'May 15, 2026': [...], 'May 14, 2026': [...] }

  return (
    <div>
      <input
        placeholder="Filter by actor..."
        value={actorFilter}
        onChange={e => setActorFilter(e.target.value)}
      />

      {Object.entries(grouped).map(([day, dayEvents]) => (
        <div key={day}>
          <div className="day-separator">{day}</div>
          {dayEvents.map(event => (
            <ActivityEvent key={event.id} event={event} />
          ))}
        </div>
      ))}

      {hasNextPage && (
        <button onClick={fetchNextPage}>Load more</button>
      )}
    </div>
  );
}

function ActivityEvent({ event }) {
  const [showDiff, setShowDiff] = useState(false);

  return (
    <div className="activity-event">
      <ActorAvatar actorType={event.actorType} actorLabel={event.actorLabel} />
      <div>
        <span className="actor">
          {event.actorType === 'system'
            ? <em className="text-muted">System</em>
            : event.actorLabel}
        </span>
        <span className="action"> {formatAction(event.action)}</span>
        {event.note && <p className="note">{event.note}</p>}
        {event.changes && (
          <button onClick={() => setShowDiff(!showDiff)} className="text-sm">
            {showDiff ? 'Hide' : 'Show'} changes
          </button>
        )}
        {showDiff && <ChangeDiff changes={event.changes} />}
        <time title={event.createdAt.toISOString()}>{formatRelative(event.createdAt)}</time>
      </div>
    </div>
  );
}
```

### Logging Helper
```typescript
function logActivity(params: {
  resourceType: string;
  resourceId: string;
  actorType: 'user' | 'system' | 'api';
  actorId?: string;
  actorLabel: string;
  action: string;
  changes?: Record<string, [unknown, unknown]>;
  note?: string;
}) {
  // Non-blocking
  db.resourceActivity.create(params).catch(captureException);
}
```

## Key Rules
- Use infinite scroll, not pagination — a timeline has no concept of "page 3"
- Group events by day with sticky day separators — makes scanning much faster
- Distinguish system (automated) vs user vs API events visually — different icon/style
- Denormalize actor label (email/name) at write time — actors get deleted but their history remains
- Cursor-based pagination (by `createdAt`) instead of offset — offset breaks when new events are inserted
- Changes diff is collapsed by default — show/hide on click to avoid wall of JSON
- Filter by actor email — essential for investigating "did this user do X?"
- Log asynchronously and non-blocking — activity logging must never fail a primary operation
- Show ISO timestamp on hover even when displaying relative time (tooltip on `<time>`)
- Never allow editing or deleting activity events from the UI
