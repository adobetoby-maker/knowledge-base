# Failure: Stale Service Worker Blocking Updates

## Overview
Service workers cache application assets for offline use and performance. But once a service worker is installed, it controls all pages in its scope — including controlling the fetch of the service worker file itself. This means users can get stuck with an old service worker indefinitely: the browser checks for updates but if the activation is blocked (waiting for all tabs to close), users with long-lived sessions never get the new version. The result is users running weeks-old code after a "deployment."

## The Update Lifecycle Problem

```
1. User visits app → service-worker.js v1 installed and activated
2. You deploy v2 → service-worker.js v2 downloaded in background
3. v2 is in "waiting" state — won't activate until all tabs with v1 are closed
4. User never closes their tab → they run v1 forever
5. Weeks later, user still on v1 with bugs you fixed in v2
```

## Fix 1: skipWaiting + clientsClaim

```js
// service-worker.js
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open('app-v2').then(cache => cache.addAll([
      '/', '/app.js', '/styles.css'
    ]))
  )
  // Don't wait for tabs to close — activate immediately
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    // Clean up old caches
    caches.keys().then(keys =>
      Promise.all(
        keys.filter(key => key !== 'app-v2')
            .map(key => caches.delete(key))
      )
    )
  )
  // Take control of all existing clients immediately
  self.clients.claim()
})
```

## Fix 2: Detect update and prompt user to refresh

```ts
// In your app's service worker registration
async function registerServiceWorker() {
  if (!('serviceWorker' in navigator)) return

  const registration = await navigator.serviceWorker.register('/service-worker.js')

  // Detect new service worker waiting
  registration.addEventListener('updatefound', () => {
    const newWorker = registration.installing
    if (!newWorker) return

    newWorker.addEventListener('statechange', () => {
      if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
        // New version is available but waiting
        showUpdatePrompt()
      }
    })
  })

  // Also check on focus (user returns to tab after long time)
  window.addEventListener('focus', () => {
    registration.update()
  })
}

// Show update prompt using safe DOM APIs — no innerHTML with untrusted content
function showUpdatePrompt() {
  const container = document.createElement('div')
  Object.assign(container.style, {
    position: 'fixed', bottom: '16px', left: '50%', transform: 'translateX(-50%)',
    background: '#1e293b', color: 'white', padding: '12px 16px',
    borderRadius: '8px', display: 'flex', alignItems: 'center',
    gap: '12px', zIndex: '9999',
  })

  const message = document.createElement('span')
  message.textContent = 'A new version is available'

  const button = document.createElement('button')
  button.textContent = 'Update'
  Object.assign(button.style, {
    background: '#3b82f6', border: 'none', color: 'white',
    padding: '4px 12px', borderRadius: '4px', cursor: 'pointer',
  })
  button.addEventListener('click', async () => {
    const reg = await navigator.serviceWorker.getRegistration()
    reg?.waiting?.postMessage({ type: 'SKIP_WAITING' })
    window.location.reload()
  })

  container.appendChild(message)
  container.appendChild(button)
  document.body.appendChild(container)
}
```

### Handling the SKIP_WAITING message in the service worker

```js
// service-worker.js
self.addEventListener('message', (event) => {
  if (event.data?.type === 'SKIP_WAITING') {
    self.skipWaiting()
  }
})
```

## Fix 3: Version manifest for staleness detection

```ts
// Serve a version file that changes with each deployment
// /public/version.json → { "version": "2.5.1", "deployedAt": "2026-05-15T10:00:00Z" }

async function checkAppVersion() {
  try {
    const res = await fetch('/version.json', { cache: 'no-store' })
    const { version } = await res.json()
    const currentVersion = document.querySelector('meta[name="app-version"]')?.getAttribute('content')

    if (currentVersion && version !== currentVersion) {
      window.location.reload()
    }
  } catch {}
}

// Check every 30 minutes and on focus
setInterval(checkAppVersion, 30 * 60 * 1000)
window.addEventListener('focus', checkAppVersion)
```

## Fix 4: Workbox configuration (if using Workbox)

```js
// workbox-config.js
module.exports = {
  skipWaiting: true,      // Maps to self.skipWaiting()
  clientsClaim: true,     // Maps to self.clients.claim()
  cleanupOutdatedCaches: true,
}
```

## Testing the Update Flow

```
In DevTools > Application > Service Workers:
1. Check "Update on reload" during development
2. Click "Skip waiting" to manually test activation
3. Use "Unregister" to reset and test full install flow

Test with two tabs:
- Tab 1: app running with service worker v1
- Tab 2: navigate to app — new service worker downloaded, enters "waiting" state
- Expected: Tab 1 shows update prompt
- Click update → both tabs reload with new version
```

## Key Rules
- `skipWaiting()` in `install` + `clientsClaim()` in `activate` enables immediate takeover
- Without `skipWaiting`, the new service worker waits for all tabs to close — users with long sessions never update
- Show a non-intrusive "Update available" prompt rather than silently forcing reloads mid-task
- `registration.update()` on `focus` checks for updates when users return after a long absence
- Version manifest polling is a belt-and-suspenders approach alongside the SW update mechanism
- Always clean up old cache entries in `activate` — stale caches consume storage and serve old assets
- Test the update flow explicitly: it cannot be relied upon to behave intuitively — browser varies
