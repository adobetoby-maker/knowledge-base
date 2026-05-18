# Disambig: Real-Time Approach

## Does It Actually Need to Be Real-Time?

Before choosing a real-time approach, confirm the requirement:
- Does the user need to see changes from OTHER users without refreshing? → Real-time
- Does the user need confirmation that THEIR action worked? → Toast + mutation, not real-time
- Does the data change rarely (< once per minute)? → Polling or ISR might be simpler

## Supabase Realtime (Postgres Changes)

For listening to database changes — invoice status updates, new messages, notifications:

```typescript
// Listen to changes on the notifications table:
const channel = supabase
  .channel(`notifications:${userId}`)
  .on(
    'postgres_changes',
    { event: 'INSERT', schema: 'public', table: 'notifications', filter: `user_id=eq.${userId}` },
    (payload) => {
      setNotifications(prev => [payload.new as Notification, ...prev])
    }
  )
  .subscribe()

// Cleanup (required — memory leak without this):
return () => { supabase.removeChannel(channel) }
```

Requirements:
- RLS must allow the user to SELECT the rows they're subscribing to
- Channel names must be unique per subscription (not reused across concurrent subscriptions)
- Always clean up in `useEffect` return

## Supabase Realtime (Broadcast)

For ephemeral real-time events NOT backed by the database — cursor positions, presence indicators, typing notifications:

```typescript
const channel = supabase.channel('room:typing')

// Send:
channel.send({ type: 'broadcast', event: 'typing', payload: { userId } })

// Receive:
channel.on('broadcast', { event: 'typing' }, ({ payload }) => {
  setTypingUsers(prev => [...new Set([...prev, payload.userId])])
})

channel.subscribe()
```

Broadcast events are not stored in the database — they fire and forget.

## Polling (Simple Alternative)

For data that updates occasionally and exact immediacy isn't required:

```typescript
// TanStack Query with polling interval:
const { data } = useQuery({
  queryKey: ['invoice-status', invoiceId],
  queryFn: () => fetchInvoiceStatus(invoiceId),
  refetchInterval: 5000,  // poll every 5 seconds
  enabled: status === 'processing',  // only poll while pending
})
```

Polling is simpler to reason about than real-time subscriptions. Use it when:
- The delay is acceptable (< 30 seconds)
- The data changes rarely
- Setting up a Supabase channel feels like overkill

## When to Use Each

| Approach | When |
|---|---|
| Supabase Postgres Changes | User needs to see DB changes from others instantly |
| Supabase Broadcast | Ephemeral events (presence, typing, cursor) |
| TanStack Query polling | Eventual consistency OK, infrequent changes |
| Server-Sent Events | One-way server push, streaming results |
| WebSockets (custom) | Two-way communication, not needed for most apps |

## Avoiding Subscription Leaks

The most common realtime bug: creating a channel in a useEffect without cleaning up.

```typescript
// Every subscription needs a cleanup:
useEffect(() => {
  const channel = supabase.channel('...').on(...).subscribe()
  
  return () => {
    supabase.removeChannel(channel)  // REQUIRED
  }
}, [userId])  // recreate subscription if userId changes
```

React StrictMode in development invokes effects twice — if cleanup is missing, two subscriptions fire and the component receives duplicate events.
