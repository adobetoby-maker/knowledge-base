# Skill: Web Push Notifications

## Overview
Web Push lets you re-engage users even when your app isn't open. The browser's push service (FCM, Mozilla, etc.) delivers messages server-to-browser via VAPID-authenticated requests. Getting permission timing wrong kills opt-in rates; getting key management wrong breaks delivery silently.

## Implementation

### 1. Generate VAPID keys (one-time, store in env)
```bash
npx web-push generate-vapid-keys
# VAPID_PUBLIC_KEY=...
# VAPID_PRIVATE_KEY=...
```

### 2. Register service worker
```ts
// public/sw.js
self.addEventListener('push', (event) => {
  const data = event.data?.json() ?? {};
  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      icon: '/icon-192.png',
      badge: '/badge.png',
      data: { url: data.url },   // used in notificationclick
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.openWindow(event.notification.data.url ?? '/')
  );
});
```

```ts
// app: register SW and subscribe
async function subscribeToPush(userId: string) {
  const reg = await navigator.serviceWorker.register('/sw.js');
  await navigator.serviceWorker.ready;

  const existing = await reg.pushManager.getSubscription();
  if (existing) return existing; // already subscribed

  const sub = await reg.pushManager.subscribe({
    userVisibleOnly: true,  // required — must show notification on every push
    applicationServerKey: urlBase64ToUint8Array(process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY!),
  });

  // Persist subscription to DB
  await fetch('/api/push/subscribe', {
    method: 'POST',
    body: JSON.stringify({ userId, subscription: sub.toJSON() }),
  });

  return sub;
}
```

### 3. Store subscription in DB
```sql
CREATE TABLE push_subscriptions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES users(id) ON DELETE CASCADE,
  endpoint    text NOT NULL UNIQUE,
  keys        jsonb NOT NULL,  -- { p256dh, auth }
  created_at  timestamptz DEFAULT now()
);
```

### 4. Send push from server
```ts
import webpush from 'web-push';

webpush.setVapidDetails(
  'mailto:admin@example.com',
  process.env.VAPID_PUBLIC_KEY!,
  process.env.VAPID_PRIVATE_KEY!
);

async function sendPush(subscription: PushSubscription, payload: object) {
  try {
    await webpush.sendNotification(
      subscription,
      JSON.stringify(payload),
      { TTL: 86400 }  // 24h — drop if user offline longer
    );
  } catch (err: any) {
    if (err.statusCode === 410 || err.statusCode === 404) {
      // Subscription expired — remove from DB
      await db.delete(pushSubscriptions).where(eq(pushSubscriptions.endpoint, subscription.endpoint));
    }
    throw err;
  }
}
```

### 5. Helper: base64 → Uint8Array
```ts
function urlBase64ToUint8Array(base64: string): Uint8Array {
  const padded = base64.replace(/-/g, '+').replace(/_/g, '/');
  const raw = atob(padded);
  return new Uint8Array([...raw].map(c => c.charCodeAt(0)));
}
```

## Key Rules
- **Never prompt for permission on page load** — always trigger after a user action (button click, completing onboarding). Cold prompts get denied at 80%+ rates.
- Remove 410/404 subscriptions immediately — stale endpoints waste resources and can block delivery queues.
- `userVisibleOnly: true` is mandatory in Chrome — every push must show a notification.
- Store `endpoint` + `keys.p256dh` + `keys.auth` separately from subscription JSON; the object structure varies by browser.
- Set TTL on sends: 0 = deliver now or drop, 86400 = try for 24h.
- Rotate VAPID keys only if compromised — rotation invalidates all subscriptions.
- Test in incognito: service workers behave differently with cached registrations.
