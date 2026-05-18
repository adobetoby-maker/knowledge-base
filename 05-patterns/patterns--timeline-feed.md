# Pattern: Timeline / Activity Feed

## What This Solves

Activity logs, audit trails, event histories, and social feeds share a structure: ordered events with timestamps, actor info, and a description. The challenge is: rendering the vertical line that connects events, grouping by date, and loading more without losing scroll position.

## Basic Timeline

```tsx
// components/Timeline.tsx
import { formatDistanceToNow } from 'date-fns'

interface TimelineEvent {
  id: string
  actor: { name: string; avatar_url: string | null }
  action: string
  description: string
  created_at: string
}

export function Timeline({ events }: { events: TimelineEvent[] }) {
  return (
    <ol className="relative">
      {events.map((event, index) => (
        <li key={event.id} className="relative pl-10 pb-8 last:pb-0">
          {/* Vertical connector line */}
          {index < events.length - 1 && (
            <div className="absolute left-3.5 top-8 bottom-0 w-px bg-border" />
          )}

          {/* Dot */}
          <div className="absolute left-0 flex h-7 w-7 items-center justify-center rounded-full border-2 border-background bg-muted ring-2 ring-border">
            <Avatar className="h-5 w-5">
              <AvatarImage src={event.actor.avatar_url ?? undefined} />
              <AvatarFallback className="text-xs">{event.actor.name[0]}</AvatarFallback>
            </Avatar>
          </div>

          <div className="flex flex-col gap-0.5">
            <p className="text-sm">
              <span className="font-medium">{event.actor.name}</span>
              {' '}
              <span className="text-muted-foreground">{event.action}</span>
              {' '}
              <span>{event.description}</span>
            </p>
            <time className="text-xs text-muted-foreground">
              {formatDistanceToNow(new Date(event.created_at), { addSuffix: true })}
            </time>
          </div>
        </li>
      ))}
    </ol>
  )
}
```

## Date-Grouped Timeline

```tsx
import { groupBy } from 'lodash-es'
import { format, isToday, isYesterday } from 'date-fns'

function formatGroupLabel(dateStr: string): string {
  const date = new Date(dateStr)
  if (isToday(date)) return 'Today'
  if (isYesterday(date)) return 'Yesterday'
  return format(date, 'MMMM d, yyyy')
}

export function GroupedTimeline({ events }: { events: TimelineEvent[] }) {
  const grouped = groupBy(events, e => format(new Date(e.created_at), 'yyyy-MM-dd'))

  return (
    <div className="space-y-6">
      {Object.entries(grouped).map(([date, dayEvents]) => (
        <div key={date}>
          <div className="sticky top-16 z-10 -mx-4 px-4 py-1.5 bg-muted/80 backdrop-blur text-xs font-medium text-muted-foreground border-y">
            {formatGroupLabel(date)}
          </div>
          <Timeline events={dayEvents} />
        </div>
      ))}
    </div>
  )
}
```

## Load More / Infinite Feed

```tsx
function ActivityFeed({ entityId }: { entityId: string }) {
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteQuery({
    queryKey: ['activity', entityId],
    queryFn: async ({ pageParam = 0 }) => {
      const { data } = await supabase
        .from('audit_log')
        .select('id, actor_id, action, description, created_at, profiles(name, avatar_url)')
        .eq('entity_id', entityId)
        .order('created_at', { ascending: false })
        .range(pageParam, pageParam + 19)
      return data ?? []
    },
    getNextPageParam: (last, pages) => last.length === 20 ? pages.length * 20 : undefined,
    initialPageParam: 0,
  })

  const allEvents = data?.pages.flat() ?? []

  return (
    <div>
      <GroupedTimeline events={allEvents} />
      {hasNextPage && (
        <Button
          variant="ghost"
          size="sm"
          onClick={() => fetchNextPage()}
          disabled={isFetchingNextPage}
          className="mt-4 w-full"
        >
          {isFetchingNextPage ? 'Loading...' : 'Load more'}
        </Button>
      )}
    </div>
  )
}
```

## Real-Time Updates

```tsx
useEffect(() => {
  const channel = supabase
    .channel(`activity-${entityId}`)
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'audit_log',
      filter: `entity_id=eq.${entityId}`,
    }, () => {
      queryClient.invalidateQueries({ queryKey: ['activity', entityId] })
    })
    .subscribe()

  return () => { supabase.removeChannel(channel) }
}, [entityId])
```

## Audit Log DB Pattern

```sql
CREATE TABLE audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type text NOT NULL,   -- 'invoice', 'client', etc.
  entity_id uuid NOT NULL,
  actor_id uuid REFERENCES auth.users,
  action text NOT NULL,        -- 'created', 'updated', 'status_changed'
  description text,
  metadata jsonb,              -- { old_status: 'draft', new_status: 'sent' }
  created_at timestamptz DEFAULT now()
);

CREATE INDEX audit_log_entity ON audit_log(entity_id, created_at DESC);
```

Write to this table in Route Handlers / Server Actions after any significant mutation. Never let audit log writes block or throw in the primary action.
