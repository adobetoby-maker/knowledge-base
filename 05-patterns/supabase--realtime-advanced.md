# Supabase Realtime — Advanced Patterns

## What Realtime Can Do

Supabase Realtime provides:
1. **Broadcast:** Send/receive arbitrary messages via named channels (not tied to database)
2. **Presence:** Track who is currently connected to a channel (online users, cursors)
3. **Postgres Changes:** Subscribe to database row inserts/updates/deletes in real-time

## Postgres Changes — Subscribe to Table Changes

```typescript
'use client'
import { useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'

export function useInvoiceUpdates(userId: string, onUpdate: (payload: any) => void) {
  const supabase = createClient()
  
  useEffect(() => {
    const channel = supabase
      .channel('invoice-changes')
      .on(
        'postgres_changes',
        {
          event: '*',          // INSERT | UPDATE | DELETE | *
          schema: 'public',
          table: 'invoices',
          filter: `user_id=eq.${userId}`,  // only this user's invoices
        },
        (payload) => {
          onUpdate(payload)
        }
      )
      .subscribe()
    
    return () => {
      supabase.removeChannel(channel)
    }
  }, [userId])
}
```

The filter matches Supabase's row filter syntax. Complex filters use the same operators as the query builder.

## Broadcast — Real-Time Messaging

For features like live collaboration, notifications, or multiplayer:

```typescript
// Sender
const channel = supabase.channel('room:battle-123')

channel.send({
  type: 'broadcast',
  event: 'player_move',
  payload: { playerId: 'user-1', position: { x: 5, y: 3 } }
})

// Receiver
channel
  .on('broadcast', { event: 'player_move' }, (payload) => {
    updatePlayerPosition(payload.payload)
  })
  .subscribe()
```

## Presence — Track Connected Users

```typescript
const channel = supabase.channel('room:battle-123', {
  config: { presence: { key: userId } }
})

// Track current user's presence
channel.subscribe(async (status) => {
  if (status === 'SUBSCRIBED') {
    await channel.track({
      user_id: userId,
      username: user.name,
      online_at: new Date().toISOString(),
    })
  }
})

// Get all connected users
channel.on('presence', { event: 'sync' }, () => {
  const state = channel.presenceState()
  const onlineUsers = Object.values(state).flat()
  setOnlineUsers(onlineUsers)
})

// Cleanup
channel.on('presence', { event: 'leave' }, ({ leftPresences }) => {
  console.log('User left:', leftPresences)
})
```

## language-lens-elite Multiplayer Pattern

In language-lens-elite, the Match tab uses Supabase Realtime for multiplayer matchmaking and game state sync. Key implementation detail: the `match-state.tsx` provider manages the Realtime channel lifecycle, not individual game components.

```typescript
// State machine for match lifecycle
type MatchPhase = 'idle' | 'searching' | 'matched' | 'in-game' | 'complete'
```

The rank tier system (Bronze → Unreal) is separate from the XP tier (Beginner → Maestro). Never conflate them in match state.

## Channel Cleanup

Always unsubscribe when components unmount. Orphaned channels consume server resources and may cause stale listeners:

```typescript
useEffect(() => {
  const channel = supabase.channel('my-channel')
  // ... setup ...
  channel.subscribe()
  
  return () => {
    channel.unsubscribe()
    // Or to remove completely:
    // supabase.removeChannel(channel)
  }
}, [])
```

## Checking Realtime Status

```typescript
channel.subscribe((status, err) => {
  if (status === 'SUBSCRIBED') {
    console.log('Connected to channel')
  } else if (status === 'CHANNEL_ERROR') {
    console.error('Channel error:', err)
  } else if (status === 'TIMED_OUT') {
    console.warn('Connection timed out — will retry')
  }
})
```

Handle errors and timeouts — Realtime connections can drop on mobile networks.

## Row Level Security with Realtime

Realtime respects RLS policies on Postgres Changes. Users only receive updates for rows they can SELECT. If updates aren't being received, verify:
1. RLS SELECT policy allows the user to see these rows
2. The filter matches existing rows
3. `SUPABASE_URL` is correct (Realtime uses a websocket connection to the same host)

## Performance Considerations

- Each subscription is a websocket connection. Don't create more than 5-10 per client.
- Use filters to narrow subscription scope — receiving all row changes for a large table is expensive.
- Broadcast is cheaper than Postgres Changes for high-frequency updates — it doesn't go through the database.
- Presence sync fires on every join/leave — if many users connect rapidly, debounce the handler.
