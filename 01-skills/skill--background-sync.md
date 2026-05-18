# Skill: Background Data Sync (Offline Mutations)

## Overview
Background Sync lets a web application defer network operations until connectivity is restored. Without it, mutations made while offline are lost on page close. With it, the browser queues the operation, retains it across browser restarts, and fires the `sync` event when online — even if the original page is no longer open. The correct implementation requires both the Service Worker Background Sync API (for browsers that support it) and an in-app fallback (for browsers that don't, and for mutations where the page stays open).

## Implementation

### Service Worker Registration
```ts
// In your app startup (e.g., layout.tsx or app/_sw-registration.ts)
export async function registerServiceWorker() {
  if ('serviceWorker' in navigator) {
    try {
      const registration = await navigator.serviceWorker.register('/sw.js');
      console.log('SW registered:', registration.scope);
    } catch (err) {
      console.error('SW registration failed:', err);
    }
  }
}
```

### Service Worker (public/sw.js)
```js
// Background Sync event handler
self.addEventListener('sync', async (event) => {
  if (event.tag === 'sync-mutations') {
    event.waitUntil(processMutationQueue());
  }
});

async function processMutationQueue() {
  const queue = await getQueueFromIndexedDB();

  for (const mutation of queue) {
    try {
      const res = await fetch(mutation.url, {
        method: mutation.method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(mutation.body),
      });

      if (res.ok) {
        await removeFromQueue(mutation.id);
      } else if (res.status >= 400 && res.status < 500) {
        // Client error — remove from queue (won't succeed on retry)
        await markFailed(mutation.id, await res.text());
      }
      // 5xx: leave in queue for next sync attempt
    } catch (err) {
      // Network error: leave in queue
    }
  }
}
```

### Enqueueing Mutations from the App
```ts
interface QueuedMutation {
  id: string;
  url: string;
  method: 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  body: unknown;
  createdAt: number;
  attempts: number;
}

// IndexedDB wrapper for the mutation queue
const DB_NAME = 'app-sync-queue';
const STORE_NAME = 'mutations';

async function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => {
      req.result.createObjectStore(STORE_NAME, { keyPath: 'id' });
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function enqueueMutation(mutation: Omit<QueuedMutation, 'id' | 'createdAt' | 'attempts'>) {
  const db = await openDB();
  const entry: QueuedMutation = {
    ...mutation,
    id: crypto.randomUUID(),
    createdAt: Date.now(),
    attempts: 0,
  };

  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    const req = tx.objectStore(STORE_NAME).add(entry);
    req.onsuccess = () => resolve();
    req.onerror = () => reject(req.error);
  });

  // Request background sync
  if ('serviceWorker' in navigator && 'SyncManager' in window) {
    const registration = await navigator.serviceWorker.ready;
    await registration.sync.register('sync-mutations');
  }
}
```

### App-Layer Fallback (for unsupported browsers)
```ts
// React hook that handles both Background Sync and in-app sync
function useOfflineMutate() {
  const online = useNetworkStatus(); // from patterns--connection-status-banner

  const mutate = async (url: string, method: string, body: unknown) => {
    if (online) {
      // Attempt immediately
      try {
        const res = await fetch(url, {
          method,
          body: JSON.stringify(body),
          headers: { 'Content-Type': 'application/json' },
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return await res.json();
      } catch (err) {
        // Failed even though online — fall through to queue
        await enqueueMutation({ url, method: method as any, body });
        throw err;
      }
    } else {
      // Queue for later
      await enqueueMutation({ url, method: method as any, body });
      // Return optimistic response
      return { queued: true };
    }
  };

  // Flush queue when coming back online (fallback for no Background Sync support)
  useEffect(() => {
    if (online && !('SyncManager' in window)) {
      flushQueue();
    }
  }, [online]);

  return { mutate };
}
```

### Queue Count in UI
Show users that there are pending operations:
```tsx
function SyncQueueBadge() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    getQueueCount().then(setCount);
    const interval = setInterval(() => getQueueCount().then(setCount), 5000);
    return () => clearInterval(interval);
  }, []);

  if (count === 0) return null;
  return (
    <span aria-label={`${count} changes pending sync`}>
      {count} pending
    </span>
  );
}
```

## Key Rules
- Background Sync is a progressive enhancement — always implement an in-app fallback for browsers without `SyncManager`.
- The service worker `sync` event may fire minutes or hours after the mutation was queued — operations must be idempotent (use an idempotency key in the queue entry).
- Remove mutations from the queue only on successful HTTP 2xx response — 5xx errors are transient and should retry; 4xx errors are permanent failures.
- Cap the queue size (e.g., 100 items) and age (e.g., 7 days) — stale operations should not be sent silently.
- Show the queue count in the UI — users need visibility into "changes waiting to sync."
- The service worker file must be at the root scope (`/sw.js`) to control all pages; a nested path limits its scope.
- IndexedDB persists across browser sessions; `localStorage` does not survive the tab being closed in some browsers — IndexedDB is the correct storage for the mutation queue.
