# Real-Time Data Synchronization

## Why Optimistic Updates Matter

The perceived speed of an app is determined by how quickly the UI responds, not how quickly the server confirms. Optimistic updates apply changes locally before the round-trip completes. The risk is divergence — if the server rejects the change, the UI must roll back cleanly. The contract: apply immediately, reconcile asynchronously, roll back gracefully.

## Supabase Realtime Channels

Supabase Realtime has two patterns:

**Broadcast** — low-latency pub/sub, no DB persistence. Use for ephemeral state (cursor position, presence indicators, "user is typing").

**Postgres Changes** — subscribes to WAL events on a table. Use for persistent data changes that all clients need.

```ts
const channel = supabase
  .channel('room:tasks')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'tasks',
    filter: `project_id=eq.${projectId}`,
  }, (payload) => reconcile(payload))
  .subscribe();
```

Always filter by a tenant/resource ID — subscribing to an entire table without a filter creates O(n) fanout on the server and exposes data across users.

## Optimistic Update Pattern

```
1. Generate temp ID (uuid) for new record
2. Apply change to local state immediately
3. Send mutation to server
4. On success: replace temp ID with server ID
5. On failure: remove temp record, surface error, optionally queue retry
```

The key to clean rollback is keeping the optimistic state separately from confirmed state, or tagging records with `{ optimistic: true }`. Never merge an optimistic record into a confirmed list without removing the tag — stale optimistic records become ghost data.

## Conflict Resolution

**Last-write-wins (LWW)**: Server timestamp wins. Simple, but two users editing simultaneously lose one person's work silently. Acceptable for low-contention updates (user profile fields).

**Version vectors / CRDTs**: Each client tracks a vector clock. Merges are deterministic and order-independent. Use for collaborative text editing, shared lists, or any scenario where concurrent edits must both survive.

**Optimistic lock (version field)**: Mutation includes the version number the client last saw. Server rejects if version has advanced. Client re-fetches and re-applies. Good middle ground — explicit conflict detection without CRDT complexity.

```sql
update tasks set title = $1, version = version + 1
where id = $2 and version = $3  -- $3 = client's last-known version
returning *;
```

If 0 rows updated, a conflict occurred — surface it to the user.

## Presence Indicators

"Alice is viewing this document" uses Broadcast + Supabase Presence:

```ts
channel.track({ user_id: userId, name: userName, cursor_x: x, cursor_y: y });

channel.on('presence', { event: 'sync' }, () => {
  const state = channel.presenceState(); // { [presenceKey]: [{user_id, name}] }
  renderPresence(Object.values(state).flat());
});
```

Presence state auto-clears when a client disconnects (heartbeat TTL ~30s). Don't use the DB for presence — the round-trip latency makes it useless for live indicators.

## Offline Queue

Users disconnect. Changes made offline must survive and sync when reconnected.

```ts
// On write attempt while offline:
offlineQueue.push({ id: uuid(), type: 'UPDATE_TASK', payload, timestamp: Date.now() });

// On reconnect:
for (const op of offlineQueue.drain()) {
  try {
    await applyOperation(op);
  } catch (conflict) {
    await handleConflict(op, conflict); // show UI or auto-resolve
  }
}
```

Use `navigator.onLine` + the Supabase client's connection state event, not just network reachability. A client can be online but the Realtime socket dropped.

Persist the queue to IndexedDB or localStorage — memory queue is lost on tab close.

## Subscription Cleanup

Always unsubscribe on component unmount. Leaked subscriptions accumulate — each one holds a WebSocket slot on the server and fires events into a dead component.

```ts
useEffect(() => {
  const channel = supabase.channel(...).subscribe();
  return () => { supabase.removeChannel(channel); };
}, [projectId]);
```

Re-subscribe when the resource ID changes (the dependency array above) rather than trying to modify an existing subscription.

## Key Rules

- **Filter subscriptions** by tenant/resource ID — never subscribe to a whole table.
- **Tag optimistic records** so rollback is unambiguous.
- Choose conflict strategy **before** you build: LWW for low-contention, version lock for moderate, CRDTs for collaborative.
- **Presence goes through Broadcast/Presence**, not the database.
- **Persist offline queue** to IndexedDB — memory is lost on tab close.
- **Unsubscribe on unmount** — leaked subscriptions exhaust server WebSocket slots.
- Never trust the client clock for conflict resolution — use server-generated timestamps.
