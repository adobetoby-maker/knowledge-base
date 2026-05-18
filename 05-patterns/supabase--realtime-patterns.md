# Supabase Realtime Patterns

## Three Realtime Channels

**Postgres Changes** — listen to database table changes (INSERT, UPDATE, DELETE). Fires when data changes via any source.

**Broadcast** — arbitrary messages between clients via channel name. Used for ephemeral events (cursor positions, typing indicators).

**Presence** — track who is online in a channel. Returns a list of connected users with metadata.

## Postgres Changes

```typescript
'use client'
import { createClient } from '@/lib/supabase/client'
import { useEffect, useState } from 'react'

export function LiveInvoiceList({ userId }: { userId: string }) {
  const [invoices, setInvoices] = useState<Invoice[]>([])
  const supabase = createClient()

  useEffect(() => {
    // Initial load
    supabase
      .from('invoices')
      .select('*')
      .eq('user_id', userId)
      .then(({ data }) => setInvoices(data ?? []))

    // Subscribe to changes
    const channel = supabase
      .channel('invoices-changes')
      .on(
        'postgres_changes',
        {
          event: '*',  // INSERT | UPDATE | DELETE | *
          schema: 'public',
          table: 'invoices',
          filter: `user_id=eq.${userId}`,
        },
        (payload) => {
          if (payload.eventType === 'INSERT') {
            setInvoices(prev => [payload.new as Invoice, ...prev])
          } else if (payload.eventType === 'UPDATE') {
            setInvoices(prev => prev.map(inv =>
              inv.id === payload.new.id ? payload.new as Invoice : inv
            ))
          } else if (payload.eventType === 'DELETE') {
            setInvoices(prev => prev.filter(inv => inv.id !== payload.old.id))
          }
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)  // CRITICAL: cleanup on unmount
    }
  }, [userId])

  return <InvoiceList invoices={invoices} />
}
```

## Broadcast (Ephemeral Events)

Used in language-lens-elite for multiplayer match signaling:

```typescript
'use client'
import { createClient } from '@/lib/supabase/client'

export function useMatchChannel(matchId: string, userId: string) {
  const supabase = createClient()

  useEffect(() => {
    const channel = supabase.channel(`match:${matchId}`)

    // Listen for opponent's answers
    channel.on('broadcast', { event: 'answer' }, ({ payload }) => {
      if (payload.userId !== userId) {
        handleOpponentAnswer(payload)
      }
    })

    channel.subscribe()
    
    return () => { supabase.removeChannel(channel) }
  }, [matchId, userId])

  function sendAnswer(answer: string) {
    supabase.channel(`match:${matchId}`).send({
      type: 'broadcast',
      event: 'answer',
      payload: { userId, answer, timestamp: Date.now() },
    })
  }

  return { sendAnswer }
}
```

## Presence (Who's Online)

```typescript
'use client'
import { createClient } from '@/lib/supabase/client'
import { useEffect, useState } from 'react'

interface UserPresence {
  userId: string
  username: string
  status: 'online' | 'away'
}

export function usePresence(roomId: string, currentUser: UserPresence) {
  const [onlineUsers, setOnlineUsers] = useState<UserPresence[]>([])
  const supabase = createClient()

  useEffect(() => {
    const channel = supabase.channel(`room:${roomId}`)

    channel
      .on('presence', { event: 'sync' }, () => {
        const state = channel.presenceState()
        const users = Object.values(state).flat() as UserPresence[]
        setOnlineUsers(users)
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          await channel.track(currentUser)
        }
      })

    return () => { supabase.removeChannel(channel) }
  }, [roomId])

  return { onlineUsers }
}
```

## RLS with Realtime

Postgres Changes respects RLS policies. If a user's RLS policy prevents them from reading a row, they won't receive realtime updates for it either.

Important: ensure RLS is enabled on tables you subscribe to. Without RLS, all changes are broadcast to all subscribers.

```sql
-- Enable realtime for a table (Supabase dashboard or migration)
ALTER PUBLICATION supabase_realtime ADD TABLE invoices;

-- RLS policy example — users only receive their own invoice changes
CREATE POLICY "Users receive own invoice changes"
ON invoices FOR SELECT
USING (auth.uid() = user_id);
```

## Channel Cleanup

Always clean up channels on unmount. Memory leaks and ghost subscriptions cause performance issues and unexpected behavior:

```typescript
useEffect(() => {
  const channel = supabase.channel('room')
  channel.subscribe()
  
  return () => {
    channel.unsubscribe()          // stop receiving messages
    supabase.removeChannel(channel) // remove the channel object
  }
}, [])
```

## Common Mistakes

- **Missing cleanup** — channels persist after component unmounts, causing ghost listeners
- **Subscribing to ALL events on a large table** — filter by user_id or FK to reduce events
- **Using for high-frequency updates** — Realtime has ~500ms latency; not suitable for real-time cursors (use Broadcast with low-latency expectations)
- **Not enabling realtime on the table** — must add table to the `supabase_realtime` publication
