# Bundle: Real-Time Features (Supabase + TanStack Query)

## Architecture Overview

Real-time in this stack uses Supabase Realtime (Postgres Changes) for database-driven updates. The pattern: TanStack Query manages the data cache, Supabase pushes change notifications, and notifications trigger cache invalidation rather than manually patching cache state.

## Full Pattern

```tsx
// hooks/useRealtimeInvoices.ts
import { useEffect } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase/client'

export function useRealtimeInvoices(userId: string) {
  const queryClient = useQueryClient()

  // Load initial data
  const query = useQuery({
    queryKey: ['invoices', userId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('invoices')
        .select('id, number, client_name, total_cents, status, created_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })

      if (error) throw error
      return data
    },
    enabled: !!userId,
  })

  // Subscribe to changes
  useEffect(() => {
    if (!userId) return

    const channel = supabase
      .channel(`invoices-${userId}`)
      .on(
        'postgres_changes',
        {
          event: '*',  // INSERT, UPDATE, DELETE
          schema: 'public',
          table: 'invoices',
          filter: `user_id=eq.${userId}`,
        },
        () => {
          // Invalidate rather than manually patch — simpler and correct
          queryClient.invalidateQueries({ queryKey: ['invoices', userId] })
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)  // CRITICAL: cleanup on unmount
    }
  }, [userId, queryClient])

  return query
}
```

## Presence (Who's Online)

```tsx
// Show who is currently viewing the same page
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase/client'

interface PresenceUser {
  userId: string
  name: string
  joinedAt: string
}

export function usePresence(roomId: string, currentUser: { id: string; name: string }) {
  const [presentUsers, setPresentUsers] = useState<PresenceUser[]>([])

  useEffect(() => {
    const channel = supabase
      .channel(`presence-${roomId}`)
      .on('presence', { event: 'sync' }, () => {
        const state = channel.presenceState<PresenceUser>()
        const users = Object.values(state).flat()
        setPresentUsers(users)
      })
      .subscribe(async (status) => {
        if (status !== 'SUBSCRIBED') return

        await channel.track({
          userId: currentUser.id,
          name: currentUser.name,
          joinedAt: new Date().toISOString(),
        })
      })

    return () => { supabase.removeChannel(channel) }
  }, [roomId, currentUser.id, currentUser.name])

  return presentUsers
}
```

## Real-Time Chat / Notifications

```tsx
// Broadcast (ephemeral, not persisted):
const channel = supabase
  .channel(`notifications-${userId}`)
  .on('broadcast', { event: 'notification' }, (payload) => {
    toast.info(payload.payload.message)
  })
  .subscribe()

// Send from any other client or server:
await supabase
  .channel(`notifications-${userId}`)
  .send({
    type: 'broadcast',
    event: 'notification',
    payload: { message: 'Your invoice was viewed' },
  })
```

## Common Mistakes

**Leak: channel not removed on unmount**
```tsx
// BAD: no cleanup
useEffect(() => {
  supabase.channel('x').on(...).subscribe()
}, [])

// GOOD: remove channel in cleanup
useEffect(() => {
  const ch = supabase.channel('x').on(...).subscribe()
  return () => { supabase.removeChannel(ch) }
}, [])
```

**Re-subscribing on every render due to object deps**
```tsx
// BAD: filter object recreated every render → new subscription every render
useEffect(() => {
  supabase.channel('x').on('postgres_changes', { filter: `id=eq.${id}` }, cb).subscribe()
}, [{ filter: `id=eq.${id}` }])  // ← object dep, always new reference

// GOOD: primitive dep
useEffect(() => {
  // Same subscription, stable dep
}, [id])
```

**Channel name collision**
```tsx
// BAD: multiple components using same channel name
supabase.channel('invoices')  // First component
supabase.channel('invoices')  // Second component — shares the first channel!

// GOOD: unique channel names
supabase.channel(`invoices-${userId}`)
supabase.channel(`invoices-list-${timestamp}`)  // Or use a UUID
```

## Performance: Don't Subscribe to Entire Tables

```ts
// BAD: subscribes to ALL changes in the table
.on('postgres_changes', { table: 'invoices' }, cb)

// GOOD: filter to only what this user needs
.on('postgres_changes', { table: 'invoices', filter: `user_id=eq.${userId}` }, cb)
```

Unfiltered table subscriptions fire for every row change from every user — high volume, most irrelevant.

## When to Use Broadcast vs Postgres Changes

| Use Case | Type |
|----------|------|
| DB row created/updated/deleted | Postgres Changes |
| UI notifications (ephemeral) | Broadcast |
| Cursor position, presence | Presence |
| Chat messages (if not storing) | Broadcast |
| Chat messages (if storing) | Postgres Changes |
