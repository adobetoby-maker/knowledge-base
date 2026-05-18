# Skill: Progressive Web App (PWA) Setup

## Overview
A PWA makes a web app installable on any device and usable offline without a native app store submission. The three mandatory pieces — HTTPS, a Web App Manifest, and a Service Worker — together satisfy the browser's installability criteria. Getting all three right from day one is far cheaper than retrofitting them.

## Implementation / Key Points

### Web App Manifest (`public/manifest.json`)
```json
{
  "name": "My Application",
  "short_name": "MyApp",
  "description": "Short description shown on install prompt",
  "start_url": "/",
  "scope": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#1a1a2e",
  "icons": [
    { "src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png" },
    { "src": "/icons/icon-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
```
Link in `<head>`: `<link rel="manifest" href="/manifest.json">`. The maskable icon fills the full icon area on Android — always provide one.

### Service Worker Registration
```ts
// src/pwa.ts — register after page load to avoid blocking
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch(console.error);
  });
}
```

### Offline Fallback Page (`public/sw.js`)
```js
const CACHE = 'v1';
const OFFLINE_URL = '/offline.html';

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll([OFFLINE_URL, '/', '/manifest.json']))
  );
});

self.addEventListener('fetch', e => {
  if (e.request.mode === 'navigate') {
    e.respondWith(
      fetch(e.request).catch(() => caches.match(OFFLINE_URL))
    );
  }
});
```

### Capturing the Install Prompt
```ts
let deferredPrompt: BeforeInstallPromptEvent | null = null;

window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault();
  deferredPrompt = e as BeforeInstallPromptEvent;
  showInstallButton();   // reveal your own UI
});

function install() {
  if (!deferredPrompt) return;
  deferredPrompt.prompt();
  deferredPrompt.userChoice.then(({ outcome }) => {
    if (outcome === 'accepted') trackInstall();
    deferredPrompt = null;
  });
}
```
Capture the prompt early; the browser only fires it once and won't fire it again for months.

### Push Notifications
```ts
const reg = await navigator.serviceWorker.ready;
const sub = await reg.pushManager.subscribe({
  userVisibleOnly: true,
  applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY)
});
// POST sub.toJSON() to your backend for storage
```

### Badge API (Unread Count)
```ts
if ('setAppBadge' in navigator) {
  navigator.setAppBadge(unreadCount);    // shows number on app icon
}
if ('clearAppBadge' in navigator) {
  navigator.clearAppBadge();
}
```

## Key Rules
- HTTPS is mandatory — Service Workers will not register on HTTP (except localhost).
- `display: "standalone"` hides the browser chrome; `minimal-ui` keeps back/refresh buttons.
- Provide icons at 192 px, 512 px, and a maskable variant — missing sizes fail Lighthouse.
- Never register the Service Worker in a blocking script; always defer until after `load`.
- Offline fallback must be pre-cached during `install` — it cannot be fetched if offline.
- `beforeinstallprompt` must be captured globally (not inside a click handler) — it fires before any interaction.
- Test installability with Chrome DevTools → Application → Manifest panel.
