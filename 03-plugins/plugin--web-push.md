# Plugin: Web Push Notifications

## Overview

Push notifications sent to the browser even when the site isn't open. Requires: HTTPS, service worker, user permission, and a VAPID key pair. Use `web-push` npm package server-side to send notifications. Reaches users who opted in without requiring a native app.

## Setup

```bash
npm install web-push
npx web-push generate-vapid-keys
```

Save the output — `VAPID_PUBLIC_KEY` goes to the frontend, `VAPID_PRIVATE_KEY` stays server-side.

## Service Worker

```js
// public/sw.js
self.addEventListener('push', event => {
  const data = event.data?.json() ?? {}
  
  event.waitUntil(
    self.registration.showNotification(data.title ?? 'New notification', {
      body: data.body ?? '',
      icon: data.icon ?? '/icon-192.png',
      badge: '/badge-72.png',
      data: { url: data.url },
      actions: data.actions ?? [],
    })
  )
})

self.addEventListener('notificationclick', event => {
  event.notification.close()
  
  const url = event.notification.data?.url ?? '/'
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clientList => {
      // Focus existing tab if open
      for (const client of clientList) {
        if (client.url.includes(url) && 'focus' in client) return client.focus()
      }
      // Otherwise open new tab
      return clients.openWindow(url)
    })
  )
})
```

## Frontend: Subscribe

```ts
async function subscribeToPush(): Promise<PushSubscription | null> {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) return null

  const permission = await Notification.requestPermission()
  if (permission !== 'granted') return null

  const registration = await navigator.serviceWorker.ready

  const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,  // Required — must be true
    applicationServerKey: urlBase64ToUint8Array(process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY!),
  })

  // Send subscription to your server
  await fetch('/api/push/subscribe', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(subscription),
  })

  return subscription
}

function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = '='.repeat((4 - base64String.length % 4) % 4)
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
  const rawData = atob(base64)
  return Uint8Array.from([...rawData].map(char => char.charCodeAt(0)))
}
```

## Server: Store Subscription

```ts
// app/api/push/subscribe/route.ts
export async function POST(req: Request) {
  const user = await requireAuth()
  const subscription = await req.json() as PushSubscription

  await db.insert(pushSubscriptions).values({
    userId: user.id,
    endpoint: subscription.endpoint,
    p256dh: subscription.keys.p256dh,
    auth: subscription.keys.auth,
  }).onConflictDoUpdate({
    target: pushSubscriptions.endpoint,
    set: { p256dh: subscription.keys.p256dh, auth: subscription.keys.auth },
  })

  return Response.json({ ok: true })
}
```

## Server: Send Notification

```ts
import webpush from 'web-push'

webpush.setVapidDetails(
  'mailto:admin@yourapp.com',  // Contact info required
  process.env.VAPID_PUBLIC_KEY!,
  process.env.VAPID_PRIVATE_KEY!,
)

async function sendPushNotification(userId: string, payload: {
  title: string
  body: string
  url?: string
  icon?: string
}) {
  const subscriptions = await db.query.pushSubscriptions.findMany({
    where: eq(pushSubscriptions.userId, userId),
  })

  const results = await Promise.allSettled(
    subscriptions.map(sub =>
      webpush.sendNotification(
        { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
        JSON.stringify(payload),
        { TTL: 86400 }  // Delivery attempt window: 24 hours
      )
    )
  )

  // Remove expired subscriptions (410 Gone = unsubscribed)
  for (const [i, result] of results.entries()) {
    if (result.status === 'rejected' && result.reason?.statusCode === 410) {
      await db.delete(pushSubscriptions).where(eq(pushSubscriptions.endpoint, subscriptions[i].endpoint))
    }
  }
}
```

## Key Rules

- `userVisibleOnly: true` is required by browsers — push must show a visible notification, no silent push.
- Remove subscriptions on 410 response — the browser unsubscribed and the endpoint is gone.
- Don't request permission on page load — wait for a user action (clicking "Enable notifications").
- TTL (Time to Live): set `86400` (24h) for important alerts; `0` for time-sensitive notifications that aren't worth delivering if missed.
- VAPID public key must be URL-safe base64 — use the `urlBase64ToUint8Array` helper when subscribing.
