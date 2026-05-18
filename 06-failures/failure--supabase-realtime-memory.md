# Failure: Supabase Realtime Channel Memory Leak

## Overview
Every call to `supabase.channel()` creates a new channel object and establishes a WebSocket connection. If `channel.subscribe()` is called without a corresponding `supabase.removeChannel(channel)` in cleanup, each render of the component that creates the channel leaves behind an orphaned connection. In React, this is catastrophic: Strict Mode mounts/unmounts components twice in development, and any component that remounts (navigation, tab switching, list re-renders) accumulates connections until the browser runs out of WebSocket slots or memory.

## The Failure Pattern

```ts
// WRONG: No cleanup — leaks a channel on every render
function LiveOrderStatus({ orderId }: { orderId: string }) {
  const [status, setStatus] = useState('pending')

  useEffect(() => {
    const channel = supabase
      .channel(`order-${orderId}`)
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'orders',
        filter: `id=eq.${orderId}`,
      }, (payload) => {
        setStatus(payload.new.status)
      })
      .subscribe()

    // Missing return cleanup function!
    // Every time this effect runs (orderId changes, Strict Mode remount, etc.):
    // - A new channel is created
    // - Old channel is never removed
    // - WebSocket connections accumulate
  }, [orderId])

  return <div>Status: {status}</div>
}
```

## The Fix: Always return cleanup

```ts
// CORRECT: Cleanup removes the channel when effect re-runs or component unmounts
function LiveOrderStatus({ orderId }: { orderId: string }) {
  const [status, setStatus] = useState('pending')

  useEffect(() => {
    const channel = supabase
      .channel(`order-${orderId}`)
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'orders',
        filter: `id=eq.${orderId}`,
      }, (payload) => {
        setStatus((payload.new as Order).status)
      })
      .subscribe()

    // CRITICAL: Return cleanup function
    return () => {
      supabase.removeChannel(channel)
    }
  }, [orderId])  // Re-subscribes when orderId changes — old channel is cleaned up first

  return <div>Status: {status}</div>
}
```

## Subscribing to multiple tables

```ts
function useLiveWorkspace(workspaceId: string) {
  const [data, setData] = useState<WorkspaceData | null>(null)

  useEffect(() => {
    // One channel, multiple listeners
    const channel = supabase
      .channel(`workspace-${workspaceId}`)
      .on('postgres_changes', {
        event: '*',  // INSERT, UPDATE, DELETE
        schema: 'public',
        table: 'members',
        filter: `workspace_id=eq.${workspaceId}`,
      }, handleMembersChange)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'projects',
        filter: `workspace_id=eq.${workspaceId}`,
      }, handleProjectsChange)
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          console.log('Realtime connected for workspace:', workspaceId)
        }
      })

    return () => {
      supabase.removeChannel(channel)
    }
  }, [workspaceId])
}
```

## Custom hook with proper cleanup

```ts
function useRealtimeTable<T extends { id: string }>({
  table,
  filter,
  onInsert,
  onUpdate,
  onDelete,
}: {
  table: string
  filter?: string
  onInsert?: (row: T) => void
  onUpdate?: (row: T) => void
  onDelete?: (row: T) => void
}) {
  useEffect(() => {
    const channelName = filter ? `${table}-${filter}` : table

    let query = supabase
      .channel(channelName)

    if (onInsert) {
      query = query.on('postgres_changes', { event: 'INSERT', schema: 'public', table, filter },
        (payload) => onInsert(payload.new as T))
    }
    if (onUpdate) {
      query = query.on('postgres_changes', { event: 'UPDATE', schema: 'public', table, filter },
        (payload) => onUpdate(payload.new as T))
    }
    if (onDelete) {
      query = query.on('postgres_changes', { event: 'DELETE', schema: 'public', table, filter },
        (payload) => onDelete(payload.old as T))
    }

    const channel = query.subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [table, filter])
}
```

## Diagnosing the leak

```ts
// Check how many active channels you have
// If this grows over time, you have a leak
console.log('Active channels:', supabase.getChannels().length)

// In React DevTools > Profiler:
// If you see channels created but not destroyed on unmount → leak

// Supabase Dashboard > Realtime > Connections:
// If connections grow steadily without dropping → clients have leaks
```

## Key Rules
- Every `supabase.channel().subscribe()` must have a corresponding `supabase.removeChannel()` in the `useEffect` cleanup return
- React Strict Mode mounts components twice in development — this surfaces channel leaks immediately (good)
- Use one channel per logical subscription scope — don't create separate channels for each table; add multiple `.on()` listeners to one channel
- Channel names should be stable and unique — using IDs in the name (`order-${orderId}`) ensures correct cleanup when IDs change
- `supabase.removeChannel(channel)` both unsubscribes and removes the channel — don't call `channel.unsubscribe()` separately
- Check `supabase.getChannels().length` in dev to verify cleanup is working
