# Real-Time Features

## When to Use Real-Time

Real-time subscriptions are appropriate when:
- Multiple users need to see changes made by others (collaborative editing, chat, leaderboards)
- The user needs immediate feedback on state changes (multiplayer game state, order status)
- Polling would create unacceptable latency or server load

NOT appropriate for:
- Single-user data that only changes on user action (invoices list — just refetch)
- Analytics dashboards (5-minute polling is fine)
- Anything that works well with "refresh to see updates"

## Supabase Real-Time Subscriptions

### Postgres Changes (Database Events)
```typescript
'use client'
import { createClient } from '@/lib/supabase/client'
import { useEffect } from 'react'

export function useRealtimeInvoices(onUpdate: (invoice: Invoice) => void) {
  const supabase = createClient()

  useEffect(() => {
    const channel = supabase
      .channel('invoices-changes')
      .on(
        'postgres_changes',
        {
          event: '*',           // INSERT | UPDATE | DELETE | *
          schema: 'public',
          table: 'invoices',
          filter: `customer_id=eq.${customerId}`,  // optional row filter
        },
        (payload) => {
          if (payload.eventType === 'INSERT') {
            onUpdate(payload.new as Invoice)
          } else if (payload.eventType === 'UPDATE') {
            onUpdate(payload.new as Invoice)
          } else if (payload.eventType === 'DELETE') {
            // payload.old has the deleted row's data
          }
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)  // REQUIRED — memory leak otherwise
    }
  }, [customerId])
}
```

### Broadcast (Ephemeral Events — No DB)
Used in `language-lens-elite` for multiplayer game state. Events are NOT stored:
```typescript
// Sender
const channel = supabase.channel(`game-${roomId}`)
channel.send({
  type: 'broadcast',
  event: 'player_move',
  payload: { playerId: user.id, position: { x, y } },
})

// Receiver
channel.on('broadcast', { event: 'player_move' }, (payload) => {
  updatePlayerPosition(payload.payload.playerId, payload.payload.position)
})
```

### Presence (Who's Online)
```typescript
const channel = supabase.channel(`room-${roomId}`)
  .on('presence', { event: 'sync' }, () => {
    const state = channel.presenceState()
    // state = { [key]: [{ user_id, online_at, ... }] }
    setOnlineUsers(Object.values(state).flat())
  })
  .subscribe(async (status) => {
    if (status === 'SUBSCRIBED') {
      await channel.track({ user_id: user.id, username: user.name })
    }
  })
```

## Combining Real-Time with TanStack Query

Real-time events should update the query cache, not maintain separate state:
```typescript
export function useInvoices() {
  const queryClient = useQueryClient()
  const supabase = createClient()

  // Subscription updates cache
  useEffect(() => {
    const channel = supabase
      .channel('invoice-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'invoices' }, (payload) => {
        if (payload.eventType === 'INSERT') {
          queryClient.setQueryData(['invoices'], (old: Invoice[] = []) => [
            payload.new as Invoice,
            ...old,
          ])
        } else if (payload.eventType === 'UPDATE') {
          queryClient.setQueryData(['invoices'], (old: Invoice[] = []) =>
            old.map((inv) => (inv.id === payload.new.id ? (payload.new as Invoice) : inv))
          )
        } else if (payload.eventType === 'DELETE') {
          queryClient.setQueryData(['invoices'], (old: Invoice[] = []) =>
            old.filter((inv) => inv.id !== payload.old.id)
          )
        }
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [queryClient])

  // Query fetches initial data
  return useQuery({
    queryKey: ['invoices'],
    queryFn: () => fetchInvoices(),
  })
}
```

## Reconnection Handling

Supabase real-time automatically reconnects. Handle the reconnect to refetch missed events:
```typescript
channel.subscribe((status, err) => {
  if (status === 'SUBSCRIBED') {
    // Refetch to catch any events missed during disconnect
    queryClient.invalidateQueries({ queryKey: ['invoices'] })
  }
  if (status === 'CHANNEL_ERROR') {
    console.error('Channel error:', err)
  }
})
```

## Unsubscribing

Always call `removeChannel` in the cleanup function:
```typescript
useEffect(() => {
  const channel = supabase.channel('...').on(...).subscribe()
  return () => {
    supabase.removeChannel(channel)  // fires on component unmount
  }
}, [])
```

Without this: channels accumulate, Supabase connection count grows, memory leaks.

## Performance: Filtering at the Source

Filter subscriptions to receive only relevant rows:
```typescript
// Only receive changes for this user's invoices
filter: `customer_id=eq.${userId}`

// Only receive changes for a specific status
filter: `status=eq.pending`
```

Without filters: every row change in the table triggers the callback. On busy tables, this is expensive.

## Real-Time vs Polling Decision

| Scenario | Approach |
|---|---|
| Multiple users editing shared data | Real-time subscription |
| Leaderboard / scores | Real-time subscription |
| Single-user dashboard | Polling every 30-60s or manual refresh |
| Order status for customer | Real-time subscription |
| Background job status | Polling every 5s |
| Analytics charts | Static with ISR revalidation |
