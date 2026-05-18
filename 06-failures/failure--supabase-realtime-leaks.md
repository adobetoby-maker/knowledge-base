# Failure Pattern: Supabase Realtime Memory Leaks

## The Problem

Supabase realtime channels are subscriptions that persist until explicitly removed. Creating channels without cleanup causes:
- Memory leaks — channels accumulate over time
- Duplicate event handlers — navigating back to a page creates a second subscription
- WebSocket connections that never close
- "too many connections" errors for high-traffic apps

## The Correct Pattern

Every `useEffect` that creates a channel MUST return a cleanup function:

```typescript
// WRONG — no cleanup:
useEffect(() => {
  const channel = supabase
    .channel('invoices')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'invoices' }, handler)
    .subscribe()
  // No cleanup → channel never removed on unmount
}, [])

// CORRECT:
useEffect(() => {
  const channel = supabase
    .channel('invoices')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'invoices' }, handler)
    .subscribe()
  
  return () => {
    supabase.removeChannel(channel)  // cleanup on unmount
  }
}, [])  // empty deps → subscribe once on mount, cleanup on unmount
```

## Channel Name Collisions

Each channel must have a unique name. If two components subscribe to the same channel name, they share a subscription (which can cause unexpected behavior):

```typescript
// WRONG — generic name could collide:
const channel = supabase.channel('notifications')

// CORRECT — scope to the component's context:
const channel = supabase.channel(`notifications-user-${userId}`)
const channel = supabase.channel(`invoices-list-page`)
const channel = supabase.channel(`invoice-detail-${invoiceId}`)
```

## React StrictMode Double-Invocation

In development, React StrictMode mounts + unmounts + remounts components to test cleanup. This means your `useEffect` runs twice: subscribe → unsubscribe → subscribe again.

If cleanup is missing, you'll see two subscriptions and doubled events. The correct cleanup pattern handles this automatically.

## Dependencies Array Trap

If you include a function in the dependencies array, it re-creates the channel on every render:

```typescript
// WRONG — 'handler' function recreated each render → channel recreated:
useEffect(() => {
  const channel = supabase.channel('x').on(..., handler).subscribe()
  return () => supabase.removeChannel(channel)
}, [handler])  // handler changes every render → infinite subscribe/unsubscribe

// CORRECT — stable handler with useCallback, or empty deps:
const handler = useCallback((payload) => {
  // handle event
}, [])  // empty deps → stable reference

useEffect(() => {
  const channel = supabase.channel('x').on(..., handler).subscribe()
  return () => supabase.removeChannel(channel)
}, [])  // or [handler] if handler is stable with useCallback
```

## Presence Channel Cleanup

Presence channels need track/untrack:

```typescript
useEffect(() => {
  const channel = supabase.channel('room')
  
  channel.on('presence', { event: 'sync' }, () => {
    const state = channel.presenceState()
    setPresence(Object.values(state).flat())
  })
  
  channel.subscribe(async (status) => {
    if (status === 'SUBSCRIBED') {
      await channel.track({ user_id: userId, online_at: new Date().toISOString() })
    }
  })
  
  return () => {
    channel.untrack()          // mark user as offline
    supabase.removeChannel(channel)
  }
}, [userId])
```

## Detecting Leaks

In development, open the browser console and check:
```javascript
// In browser console:
supabase.getChannels()
// Should have only 1 channel per subscription, not growing over time
```

If you see the count increasing with page navigation, cleanup is missing.

## Global Cleanup (App Shutdown)

For proper cleanup when the app unmounts (not usually needed but good practice):
```typescript
// In root component or provider:
useEffect(() => {
  return () => {
    supabase.removeAllChannels()  // nuclear option — removes everything
  }
}, [])
```

Use `removeAllChannels` only at the root — component-level code should use `removeChannel(specific)`.
