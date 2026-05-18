# Pattern: Activity Feed

## Overview

Show a chronological stream of events: "Alice commented on your post", "Bob followed you", "New order received". The key design decision is fan-out strategy: write-time fan-out (pre-compute each user's feed on event) vs read-time aggregation (query events on load). Write-time fan-out scales better for reads but costs more writes for high-follower users. Read-time aggregation is simpler and works fine under ~10K followers per user.

## Schema

```sql
-- Event source (what happened)
CREATE TABLE events (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id    UUID NOT NULL REFERENCES users(id),
  verb        TEXT NOT NULL,          -- 'comment', 'follow', 'like', 'order'
  object_type TEXT NOT NULL,          -- 'post', 'user', 'product'
  object_id   UUID NOT NULL,
  target_id   UUID,                   -- whose context (e.g., post owner)
  metadata    JSONB NOT NULL DEFAULT '{}',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX events_actor_created ON events(actor_id, created_at DESC);
CREATE INDEX events_target_created ON events(target_id, created_at DESC) WHERE target_id IS NOT NULL;

-- Notification fan-out (pre-computed per recipient)
CREATE TABLE notifications (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id),
  event_id   UUID NOT NULL REFERENCES events(id),
  read_at    TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX notifications_user_unread ON notifications(user_id, created_at DESC) WHERE read_at IS NULL;
```

## Feed Query (Read-Time, Simple)

```ts
async function getActivityFeed(userId: string, cursor?: string) {
  // Get IDs of users this person follows
  const followingIds = await db
    .select({ id: follows.followeeId })
    .from(follows)
    .where(eq(follows.followerId, userId))

  if (followingIds.length === 0) return { events: [], nextCursor: null }

  const ids = followingIds.map(f => f.id)

  const events = await db.query.events.findMany({
    where: and(
      inArray(events.actorId, ids),
      cursor ? lt(events.createdAt, new Date(cursor)) : undefined,
    ),
    orderBy: [desc(events.createdAt)],
    limit: 20,
    with: {
      actor: { columns: { id: true, name: true, avatarUrl: true } },
    },
  })

  return {
    events,
    nextCursor: events.length === 20 ? events[events.length - 1].createdAt.toISOString() : null,
  }
}
```

## Feed Item Component

```tsx
interface FeedItemProps {
  event: EventWithActor
}

export function FeedItem({ event }: FeedItemProps) {
  const description = formatEventDescription(event)

  return (
    <div className="flex gap-3 p-4 hover:bg-gray-50">
      <img
        src={event.actor.avatarUrl ?? '/default-avatar.png'}
        alt={event.actor.name}
        className="w-10 h-10 rounded-full flex-shrink-0"
      />
      <div className="flex-1 min-w-0">
        <p className="text-sm">
          <span className="font-semibold">{event.actor.name}</span>{' '}
          {description}
        </p>
        <FeedItemMetadata event={event} />
        <time className="text-xs text-gray-500" dateTime={event.createdAt}>
          {formatRelativeTime(event.createdAt)}
        </time>
      </div>
    </div>
  )
}

function formatEventDescription(event: EventWithActor): React.ReactNode {
  switch (event.verb) {
    case 'comment':
      return <>commented on <a href={`/posts/${event.objectId}`} className="font-medium hover:underline">your post</a></>
    case 'follow':
      return 'started following you'
    case 'like':
      return <>liked your <a href={`/posts/${event.objectId}`} className="font-medium hover:underline">post</a></>
    case 'order':
      return <>placed an order — <span className="font-medium">{event.metadata.orderNumber}</span></>
    default:
      return event.verb
  }
}
```

## Notification Unread Count

```ts
async function getUnreadCount(userId: string): Promise<number> {
  const result = await db
    .select({ count: count() })
    .from(notifications)
    .where(and(
      eq(notifications.userId, userId),
      isNull(notifications.readAt),
    ))

  return result[0]?.count ?? 0
}

async function markAllRead(userId: string): Promise<void> {
  await db
    .update(notifications)
    .set({ readAt: new Date() })
    .where(and(
      eq(notifications.userId, userId),
      isNull(notifications.readAt),
    ))
}
```

## Real-Time Updates

Subscribe to new events with Supabase Realtime:

```tsx
function useActivityFeed(userId: string) {
  const [items, setItems] = useState<Event[]>([])

  useEffect(() => {
    const channel = supabase
      .channel(`feed:${userId}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'notifications', filter: `user_id=eq.${userId}` },
        async (payload) => {
          // Fetch the full event with actor info
          const event = await fetchEvent(payload.new.event_id)
          setItems(prev => [event, ...prev].slice(0, 50))  // Keep last 50
        }
      )
      .subscribe()

    return () => { channel.unsubscribe() }
  }, [userId])

  return items
}
```

## Key Rules

- Store events in a single `events` table with `verb` + `object_type` + `object_id` — don't create separate tables per action type.
- Use `metadata JSONB` for action-specific data (order number, comment preview) — avoid nullable columns.
- Fan-out notifications at write time via a background job, not synchronously in the request handler.
- Deduplicate similar events: "5 people liked your post" (group by `verb + object_id` within 24h window).
- Cap feed to 200-500 items before querying — scanning millions of events is slow even with indexes.
