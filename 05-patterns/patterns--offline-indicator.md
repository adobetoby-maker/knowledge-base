# Pattern: Offline / Network Status Indicator

## Overview

Detect when the user loses internet connectivity and show appropriate UI. Two browser signals: `navigator.onLine` (unreliable — can be true when behind a captive portal) and `online`/`offline` events (reliable for genuine disconnection). For real connectivity verification, probe a known endpoint.

## Basic Hook

```tsx
function useOnlineStatus() {
  const [isOnline, setIsOnline] = useState(
    typeof navigator !== 'undefined' ? navigator.onLine : true
  )

  useEffect(() => {
    function handleOnline() { setIsOnline(true) }
    function handleOffline() { setIsOnline(false) }

    window.addEventListener('online', handleOnline)
    window.addEventListener('offline', handleOffline)

    return () => {
      window.removeEventListener('online', handleOnline)
      window.removeEventListener('offline', handleOffline)
    }
  }, [])

  return isOnline
}
```

## Reliable Connectivity Check

`navigator.onLine` can return `true` on hotel WiFi login walls. For operations that require real connectivity, probe an endpoint:

```ts
async function checkConnectivity(): Promise<boolean> {
  try {
    const res = await fetch('/api/ping', {
      method: 'HEAD',
      cache: 'no-cache',
      signal: AbortSignal.timeout(3000),
    })
    return res.ok
  } catch {
    return false
  }
}
```

## Offline Banner Component

```tsx
function OfflineBanner() {
  const isOnline = useOnlineStatus()
  const [showReconnected, setShowReconnected] = useState(false)
  const wasOffline = useRef(false)

  useEffect(() => {
    if (!isOnline) {
      wasOffline.current = true
    } else if (wasOffline.current) {
      // Just came back online
      setShowReconnected(true)
      const timer = setTimeout(() => setShowReconnected(false), 3000)
      return () => clearTimeout(timer)
    }
  }, [isOnline])

  if (isOnline && !showReconnected) return null

  return (
    <div
      role="alert"
      className={`fixed bottom-4 left-1/2 -translate-x-1/2 z-50 px-4 py-2 rounded-full text-sm font-medium shadow-lg transition-all ${
        isOnline
          ? 'bg-green-500 text-white'
          : 'bg-gray-900 text-white'
      }`}
    >
      {isOnline ? '✓ Back online' : '⚡ No internet connection'}
    </div>
  )
}
```

## Queue Actions While Offline

For apps where users should be able to work offline:

```ts
interface PendingAction {
  id: string
  type: string
  payload: unknown
  createdAt: number
}

const pendingQueue: PendingAction[] = []

async function performAction(type: string, payload: unknown) {
  if (!navigator.onLine) {
    pendingQueue.push({ id: crypto.randomUUID(), type, payload, createdAt: Date.now() })
    localStorage.setItem('pending-actions', JSON.stringify(pendingQueue))
    showToast('Saved locally — will sync when back online')
    return
  }

  await sendToServer(type, payload)
}

// Flush queue when back online
window.addEventListener('online', async () => {
  const queued = JSON.parse(localStorage.getItem('pending-actions') ?? '[]')
  for (const action of queued) {
    await sendToServer(action.type, action.payload)
  }
  localStorage.removeItem('pending-actions')
})
```

## Service Worker Approach

For true offline support (cached pages, offline fallback), register a service worker. The `network-first` strategy serves live data when online, falls back to cache when offline:

```js
// sw.js
self.addEventListener('fetch', event => {
  event.respondWith(
    fetch(event.request)
      .catch(() => caches.match(event.request))
  )
})
```

Use Workbox for production service workers rather than hand-rolling.

## Key Rules

- Always show a "back online" confirmation after reconnection — users need to know their connection restored.
- `navigator.onLine` alone is sufficient for most apps; full connectivity probe only needed for payment flows or critical operations.
- Don't disable form submit buttons while offline — queue the action instead so users aren't blocked.
- SSR: always default `isOnline` to `true` server-side (where `navigator` doesn't exist) to avoid hydration mismatch.
