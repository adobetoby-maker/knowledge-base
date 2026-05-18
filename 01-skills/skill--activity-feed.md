# Skill: Activity Feed

## What This Covers

Audit log as UI component — a chronological list of events in the system. Common uses: "Recent activity" on dashboard, CRM contact history, order status timeline, admin audit trail.

## Database Schema

```sql
CREATE TYPE activity_type AS ENUM (
  'invoice_created', 'invoice_sent', 'invoice_paid', 'invoice_overdue',
  'client_created', 'client_updated',
  'payment_received', 'note_added',
  'user_login', 'settings_changed'
);

CREATE TABLE activity_log (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES auth.users(id),
  type       activity_type NOT NULL,
  subject_id UUID,           -- ID of the affected entity
  subject_type TEXT,         -- 'invoice', 'client', 'payment'
  data       JSONB,          -- Type-specific data snapshot
  actor_id   UUID REFERENCES auth.users(id),  -- Who performed the action
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_activity_user ON activity_log(user_id, created_at DESC);
CREATE INDEX idx_activity_subject ON activity_log(subject_id, created_at DESC);
```

## Writing Activity Entries

```ts
// lib/activity.ts
export async function logActivity(
  userId: string,
  type: string,
  params: {
    subjectId?: string
    subjectType?: string
    data?: Record<string, unknown>
    actorId?: string
  } = {}
) {
  await supabase.from('activity_log').insert({
    user_id: userId,
    type,
    subject_id: params.subjectId,
    subject_type: params.subjectType,
    data: params.data,
    actor_id: params.actorId ?? userId,
  })
}

// Usage — after invoice is sent
await logActivity(userId, 'invoice_sent', {
  subjectId: invoice.id,
  subjectType: 'invoice',
  data: {
    invoice_number: invoice.number,
    client_name: invoice.client_name,
    total_cents: invoice.total_cents,
  },
})
```

## Fetching the Feed

```ts
// Fetch recent activity with pagination
async function getActivityFeed(userId: string, cursor?: string, limit = 20) {
  let query = supabase
    .from('activity_log')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(limit)

  if (cursor) {
    query = query.lt('created_at', cursor)
  }

  const { data, error } = await query
  if (error) throw error

  return {
    items: data ?? [],
    nextCursor: data && data.length === limit
      ? data[data.length - 1].created_at
      : null,
  }
}
```

## Activity Item Display

```ts
// Map event types to human-readable descriptions
function getActivityLabel(item: ActivityLogEntry): { icon: string; text: string } {
  const { type, data } = item

  switch (type) {
    case 'invoice_created':
      return { icon: '📄', text: `Created invoice #${data?.invoice_number}` }
    case 'invoice_sent':
      return { icon: '📧', text: `Sent invoice #${data?.invoice_number} to ${data?.client_name}` }
    case 'invoice_paid':
      return {
        icon: '✅',
        text: `Invoice #${data?.invoice_number} paid — $${((data?.total_cents as number ?? 0) / 100).toFixed(2)}`,
      }
    case 'payment_received':
      return { icon: '💰', text: `Received $${((data?.amount_cents as number ?? 0) / 100).toFixed(2)}` }
    case 'client_created':
      return { icon: '👤', text: `Added client ${data?.client_name}` }
    case 'note_added':
      return { icon: '📝', text: `Added note to ${data?.subject}` }
    default:
      return { icon: '•', text: type.replace(/_/g, ' ') }
  }
}
```

## Feed Component

```tsx
'use client'
import { useInfiniteQuery } from '@tanstack/react-query'
import { formatDistanceToNow, parseISO } from 'date-fns'

export function ActivityFeed() {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
  } = useInfiniteQuery({
    queryKey: ['activity-feed'],
    queryFn: ({ pageParam }) => getActivityFeed(undefined, pageParam),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
  })

  const items = data?.pages.flatMap((p) => p.items) ?? []

  return (
    <div>
      <div className="relative">
        {/* Vertical connector line */}
        <div className="absolute left-[19px] top-0 bottom-0 w-0.5 bg-gray-200" />

        <div className="space-y-4">
          {items.map((item) => {
            const { icon, text } = getActivityLabel(item)

            return (
              <div key={item.id} className="flex gap-3 relative">
                {/* Icon bubble */}
                <div className="w-10 h-10 rounded-full bg-white border-2 border-gray-200 flex items-center justify-center flex-shrink-0 text-lg z-10">
                  {icon}
                </div>

                {/* Content */}
                <div className="flex-1 pt-2">
                  <p className="text-sm text-gray-800">{text}</p>
                  <p className="text-xs text-gray-400 mt-0.5">
                    {formatDistanceToNow(parseISO(item.created_at), { addSuffix: true })}
                  </p>
                </div>
              </div>
            )
          })}
        </div>
      </div>

      {hasNextPage && (
        <button
          onClick={() => fetchNextPage()}
          disabled={isFetchingNextPage}
          className="mt-4 text-sm text-blue-600 hover:underline w-full text-center"
        >
          {isFetchingNextPage ? 'Loading...' : 'Load more'}
        </button>
      )}
    </div>
  )
}
```

## Subject-Specific Feed (Invoice History)

```tsx
// All events for a specific invoice
const { data } = useQuery({
  queryKey: ['activity', 'invoice', invoiceId],
  queryFn: async () => {
    const { data } = await supabase
      .from('activity_log')
      .select('*')
      .eq('subject_id', invoiceId)
      .order('created_at', { ascending: true })  // ascending for timeline view
    return data ?? []
  },
})
```

## Real-Time Activity Updates

```tsx
useEffect(() => {
  const channel = supabase
    .channel('activity-feed')
    .on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'activity_log' },
      () => queryClient.invalidateQueries({ queryKey: ['activity-feed'] })
    )
    .subscribe()

  return () => { supabase.removeChannel(channel) }
}, [])
```
