# Supabase Realtime

**When:** UI needs to update automatically when data changes — live feeds, collaborative features, chat, notifications.
**Rule:** Subscribe only to what you need. Always unsubscribe on cleanup. Realtime channels hold open WebSocket connections — uncleaned subscriptions leak memory.

## How It Works
Supabase Realtime broadcasts database changes via WebSocket.
Each subscription is a "channel" that listens to a specific table/filter/event.

## The Three Listen Types
```typescript
// 1. Postgres Changes — listens to DB row changes
channel.on('postgres_changes', {
  event: '*',      // INSERT | UPDATE | DELETE | *
  schema: 'public',
  table: 'messages',
  filter: 'room_id=eq.123'  // optional filter
}, handler)

// 2. Broadcast — custom events between clients
channel.on('broadcast', { event: 'typing' }, handler)

// 3. Presence — track who is online
channel.on('presence', { event: 'sync' }, handler)
```

## React Pattern with Cleanup
```typescript
useEffect(() => {
  const channel = supabase
    .channel('room-messages')  // unique channel name
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'messages',
      filter: `room_id=eq.${roomId}`
    }, (payload) => {
      const newMessage = payload.new as Message
      setMessages(prev => [...prev, newMessage])
    })
    .subscribe()

  return () => {
    supabase.removeChannel(channel)  // ALWAYS clean up
  }
}, [roomId])  // re-subscribe if roomId changes
```

## The Common Memory Leak
```typescript
// WRONG — subscribes every render, never unsubscribes
useEffect(() => {
  supabase.channel('messages').on(...).subscribe()
  // no return cleanup!
})

// WRONG — dependency array missing, subscribes infinitely
useEffect(() => {
  const channel = supabase.channel('messages').on(...).subscribe()
  return () => supabase.removeChannel(channel)
})  // re-runs every render — creates new channel each time
```

## Checking Realtime Connection Status
```typescript
const channel = supabase.channel('test')
  .subscribe((status) => {
    console.log('Realtime status:', status)
    // 'SUBSCRIBED' = connected
    // 'CHANNEL_ERROR' = failed
    // 'TIMED_OUT' = timeout
    // 'CLOSED' = disconnected
  })
```

## RLS and Realtime
Realtime respects RLS policies.
If a user doesn't have SELECT permission on a table, they won't receive changes for rows they can't read.
Public tables (no RLS or with `FOR SELECT USING (true)`) broadcast to all subscribers.

## When NOT to Use Realtime
- Simple data that refreshes on page navigation → use ISR or `revalidatePath`
- Data that changes rarely → polling or on-demand refresh is cheaper
- Server-side aggregations → database triggers or cron jobs are more reliable
