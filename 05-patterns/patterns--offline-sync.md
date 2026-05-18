# Pattern: Offline Queue Sync

## What This Solves

When a user performs writes while offline, those mutations need to be queued locally and replayed against the server when the connection returns. Losing the work silently is unacceptable; blocking the UI until online is frustrating. The challenge is storing mutations durably, replaying them in order, and detecting conflicts when stale offline edits collide with server state that changed while the user was disconnected.

## Why IndexedDB, Not localStorage

localStorage is synchronous, size-limited (~5MB), and can block the main thread. IndexedDB is async, has no practical size limit, and survives page reloads. Use the `idb` library to wrap IndexedDB with a promise-based API:

```ts
// lib/offline-queue.ts
import { openDB } from 'idb'

interface QueuedMutation {
  id: string          // uuid
  url: string
  method: string
  body: string        // JSON stringified
  timestamp: number
  retries: number
}

const DB_NAME = 'offline-queue'
const STORE = 'mutations'

async function getDb() {
  return openDB(DB_NAME, 1, {
    upgrade(db) {
      db.createObjectStore(STORE, { keyPath: 'id' })
    },
  })
}

export async function enqueue(mutation: Omit<QueuedMutation, 'retries'>) {
  const db = await getDb()
  await db.put(STORE, { ...mutation, retries: 0 })
}

export async function getAll(): Promise<QueuedMutation[]> {
  const db = await getDb()
  return db.getAll(STORE)
}

export async function remove(id: string) {
  const db = await getDb()
  await db.delete(STORE, id)
}

export async function incrementRetries(id: string) {
  const db = await getDb()
  const item = await db.get(STORE, id)
  if (item) await db.put(STORE, { ...item, retries: item.retries + 1 })
}
```

## Detecting Connection State

`navigator.onLine` gives the initial state but its `false` is reliable while its `true` is not — the browser may show online even when behind a captive portal. Use it as a hint, not a guarantee. Listen to the `online` event to trigger processing:

```ts
// lib/sync-manager.ts
export function initSyncManager() {
  // Process queue when connection returns
  window.addEventListener('online', processQueue)

  // Also try on initial load (in case queue from previous session)
  if (navigator.onLine) processQueue()
}
```

## Processing Queue in Order

Mutations must replay in timestamp order to preserve causal dependencies (create before update, update before delete):

```ts
async function processQueue() {
  const mutations = await getAll()
  const sorted = mutations.sort((a, b) => a.timestamp - b.timestamp)

  for (const mutation of sorted) {
    try {
      const res = await fetch(mutation.url, {
        method: mutation.method,
        headers: { 'Content-Type': 'application/json' },
        body: mutation.body,
      })

      if (res.ok) {
        await remove(mutation.id)
        continue
      }

      if (res.status === 409) {
        // Conflict: server state changed
        await handleConflict(mutation, await res.json())
        await remove(mutation.id)
        continue
      }

      if (res.status >= 400 && res.status < 500) {
        // Permanent client error — drop the mutation
        await remove(mutation.id)
        continue
      }

      // Transient server error — keep it and retry later
      await incrementRetries(mutation.id)

    } catch {
      // Network error — still offline or request failed
      await incrementRetries(mutation.id)
      break // Stop processing; still offline
    }
  }
}
```

Stop processing the queue on the first network error — there's no point attempting subsequent mutations if the connection is gone again.

## Conflict Detection

A conflict occurs when the server resource was modified after the offline mutation was captured. Detect via `ETag` or `updated_at` comparison:

```ts
// When enqueuing, capture the resource's current version
await enqueue({
  id: crypto.randomUUID(),
  url: `/api/invoices/${id}`,
  method: 'PATCH',
  body: JSON.stringify({ ...changes, _expectedVersion: currentUpdatedAt }),
  timestamp: Date.now(),
})

// Server route handler checks version before applying
// If server's updated_at !== _expectedVersion → return 409 Conflict
```

On 409, surface a conflict resolution UI rather than silently discarding the offline edit.

## Wrapping Mutations

Intercept mutations at the fetch layer so callers don't need to know about the queue:

```ts
export async function resilientFetch(url: string, init: RequestInit) {
  if (!navigator.onLine) {
    await enqueue({
      id: crypto.randomUUID(),
      url,
      method: init.method ?? 'POST',
      body: typeof init.body === 'string' ? init.body : JSON.stringify(init.body),
      timestamp: Date.now(),
    })
    // Return an optimistic "success" so the UI updates immediately
    return { ok: true, queued: true }
  }
  return fetch(url, init)
}
```

## Key Rules

- Use IndexedDB via `idb` — never localStorage for mutation queues
- Listen to the `online` event to trigger processing; also run on page load
- Replay mutations in timestamp order — order matters for dependent operations
- Stop processing on the first network error; resume on next `online` event
- Distinguish permanent errors (4xx — drop) from transient errors (5xx — retry) from conflicts (409 — surface to user)
- Capture resource version when enqueuing to enable server-side conflict detection
- Cap retries (e.g., 5) and discard mutations that consistently fail to prevent infinite retry loops
