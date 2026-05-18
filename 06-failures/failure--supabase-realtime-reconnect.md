# Failure: Supabase Realtime Channel Reconnection

## The Gap Problem

When a Realtime subscription drops and reconnects, there is a window of time where changes to the database were not delivered. The client resumes receiving new events, but any rows inserted, updated, or deleted during the outage are silently missing. If UI state was built purely from streaming events rather than a snapshot, it is now incorrect and the user has no indication anything is wrong.

This is worse than a visible error because the data looks correct but isn't.

## Always Fetch on Reconnect

The pattern: subscribe to the channel, but on reconnect (status `'SUBSCRIBED'` after a prior disconnect), re-fetch the full current dataset to close the gap.

```ts
let previousStatus: string | null = null;

const channel = supabase
  .channel('orders')
  .on(
    'postgres_changes',
    { event: '*', schema: 'public', table: 'orders' },
    (payload) => handleChange(payload)
  )
  .subscribe(async (status) => {
    if (status === 'SUBSCRIBED') {
      if (previousStatus === 'CHANNEL_ERROR' || previousStatus === 'TIMED_OUT') {
        // Reconnect — fetch to fill the gap
        const { data } = await supabase.from('orders').select('*');
        if (data) replaceAll(data);
      }
    }
    previousStatus = status;
  });
```

`replaceAll` should replace the entire local state snapshot, not merge — merging can preserve stale deletes.

## Status Callback States

The subscribe callback receives a `status` string. The states to handle:

- `'SUBSCRIBED'` — channel is live and receiving events
- `'CHANNEL_ERROR'` — channel failed to subscribe (check RLS, auth, channel config)
- `'TIMED_OUT'` — connection timed out (network issue, server restart)
- `'CLOSED'` — channel was explicitly unsubscribed

The reconnect gap pattern applies to `CHANNEL_ERROR` and `TIMED_OUT` recoveries. On the first `SUBSCRIBED` call, fetching is also correct — it initializes state at the same moment subscription begins, preventing a race where events arrive before initial data loads.

## Re-Subscription After Component Remount

React strict mode and navigation can unmount/remount components, triggering channel cleanup and re-creation. Each `useEffect` cleanup should call `supabase.removeChannel(channel)` to prevent duplicate subscriptions. Duplicate subscriptions cause duplicate event delivery.

```ts
useEffect(() => {
  const channel = supabase.channel(`room:${roomId}`)
    .on('postgres_changes', ...)
    .subscribe((status) => { /* ... */ });

  return () => {
    supabase.removeChannel(channel);
  };
}, [roomId]);
```

## Channel Naming and Uniqueness

Channel names must be unique per client. If you create two channels with the same name in the same session, Supabase may deliver events to both or neither. Include a unique identifier (user ID, record ID, route) in the channel name when the subscription is scoped.

## Presence Channels

For presence (tracking who is online), the gap problem is different: presence state is rebuilt from scratch on reconnect by the Supabase server. Fetch isn't needed — but you should call `channel.track(myState)` again after reconnect to re-announce presence, because your entry was dropped when the connection closed.

## Key Rules

- Always fetch current data on `SUBSCRIBED` status, especially after a prior error or timeout
- Track `previousStatus` to distinguish initial subscribe from reconnect
- Replace state entirely on reconnect fetch, do not merge
- Call `removeChannel` in cleanup to prevent duplicate event delivery on remount
- Include a unique ID in channel names when subscriptions are record- or user-scoped
- Re-call `channel.track()` after reconnect for presence channels
