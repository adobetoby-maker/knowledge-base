# Pattern: Offline-First UX

## Overview

`patterns--offline-indicator.md` covers detecting connectivity and showing a banner. This file covers the deeper pattern: letting users *work* offline by queuing writes to IndexedDB and flushing them when reconnected. The goal is that an offline user should be unable to tell they're offline until they try something that requires fresh server data.

## Why IndexedDB Over localStorage

`localStorage` is synchronous and blocks the main thread on large payloads. It's limited to ~5MB and stores strings only. IndexedDB is async, handles structured data natively, survives page reloads, and can hold hundreds of MB. For a request queue that needs to survive network loss, browser restarts, and multi-tab sessions, IndexedDB is the correct choice.

## Opening the Queue Store

```ts
// lib/offlineQueue.ts
const DB_NAME = 'app-offline-queue'
const STORE = 'pending'

function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1)
    req.onupgradeneeded = () => {
      req.result.createObjectStore(STORE, { keyPath: 'id' })
    }
    req.onsuccess = () => resolve(req.result)
    req.onerror = () => reject(req.error)
  })
}

export interface QueuedRequest {
  id: string
  url: string
  method: string
  body: string
  headers: Record<string, string>
  createdAt: number
}

export async function enqueue(req: Omit<QueuedRequest, 'id' | 'createdAt'>) {
  const db = await openDB()
  const tx = db.transaction(STORE, 'readwrite')
  tx.objectStore(STORE).add({
    ...req,
    id: crypto.randomUUID(),
    createdAt: Date.now(),
  })
  return new Promise<void>((resolve, reject) => {
    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error)
  })
}

export async function drainQueue(): Promise<QueuedRequest[]> {
  const db = await openDB()
  const tx = db.transaction(STORE, 'readwrite')
  const store = tx.objectStore(STORE)
  return new Promise((resolve, reject) => {
    const req = store.getAll()
    req.onsuccess = () => resolve(req.result)
    req.onerror = () => reject(req.error)
  })
}

export async function removeFromQueue(id: string) {
  const db = await openDB()
  const tx = db.transaction(STORE, 'readwrite')
  tx.objectStore(STORE).delete(id)
}
```

## Wrapping fetch with Offline Fallback

```ts
// lib/fetchWithQueue.ts
import { enqueue } from './offlineQueue'

export async function fetchWithQueue(
  url: string,
  init: RequestInit = {}
): Promise<Response | null> {
  if (navigator.onLine) {
    return fetch(url, init)
  }

  // Only queue mutating requests — reads fail loudly
  const method = (init.method ?? 'GET').toUpperCase()
  if (method === 'GET' || method === 'HEAD') {
    throw new Error('Cannot read fresh data while offline')
  }

  await enqueue({
    url,
    method,
    body: init.body ? String(init.body) : '',
    headers: (init.headers as Record<string, string>) ?? {},
  })

  // Return a synthetic 202 so callers can apply optimistic updates
  return new Response(null, { status: 202 })
}
```

Returning a `202` instead of throwing lets callers apply optimistic UI updates immediately. The actual persistence happens when the queue drains.

## Syncing on Reconnect

```ts
// lib/syncOnReconnect.ts
import { drainQueue, removeFromQueue } from './offlineQueue'

let syncInProgress = false

export async function syncPendingRequests() {
  if (syncInProgress) return
  syncInProgress = true

  const pending = await drainQueue()
  const results = await Promise.allSettled(
    pending.map(async (item) => {
      const res = await fetch(item.url, {
        method: item.method,
        body: item.body || undefined,
        headers: item.headers,
      })
      if (!res.ok) throw new Error(`${item.url} → ${res.status}`)
      await removeFromQueue(item.id)
    })
  )

  syncInProgress = false

  const failed = results.filter((r) => r.status === 'rejected')
  if (failed.length > 0) {
    console.warn(`[offline-sync] ${failed.length} requests failed to sync`)
    // Don't remove failed items — retry on next reconnect
  }
}

// Wire up at app root
if (typeof window !== 'undefined') {
  window.addEventListener('online', syncPendingRequests)
}
```

Failed items stay in the queue and retry next time. Don't silently discard them — the user's data is in there.

## Visual Feedback During Offline State

Show a pending-count badge when there are queued writes. This reassures users their changes are saved locally.

```tsx
function OfflineSyncBadge() {
  const [count, setCount] = useState(0)
  const isOnline = useOnlineStatus()

  useEffect(() => {
    if (!isOnline) {
      drainQueue().then((items) => setCount(items.length))
    } else {
      setCount(0)
    }
  }, [isOnline])

  if (isOnline || count === 0) return null

  return (
    <div role="status" className="fixed bottom-4 right-4 bg-yellow-500 text-white text-xs px-3 py-1 rounded-full shadow">
      {count} change{count !== 1 ? 's' : ''} pending sync
    </div>
  )
}
```

## Key Rules

- Never queue GET requests — stale reads are worse than a visible error. Only queue writes.
- Return `202` (not an error) from `fetchWithQueue` for writes so optimistic UI flows don't break.
- Failed sync items must stay in the queue, not be deleted silently.
- Test offline mode in DevTools → Network → "Offline", not just by toggling WiFi (the `offline` event fires differently).
- IndexedDB is async; never block the render thread waiting for it — fire-and-forget enqueue, then update UI optimistically.
- Add a queue age limit: requests older than 24 hours should be discarded with a user-visible warning rather than replayed blindly.
