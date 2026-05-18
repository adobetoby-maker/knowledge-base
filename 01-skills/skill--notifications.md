# Notifications (In-App + Push)

## In-App Notifications

### Database Schema
```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,           -- 'invoice_paid', 'new_message', 'system'
  title TEXT NOT NULL,
  body TEXT,
  data JSONB DEFAULT '{}',      -- action link, entity ID, etc.
  read_at TIMESTAMPTZ,          -- null = unread
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX notifications_user_id_read_at ON notifications(user_id, read_at)
  WHERE read_at IS NULL;        -- partial index for unread notifications
```

### Notification Bell Component
```typescript
'use client'
import { createClient } from '@/lib/supabase/client'
import { useEffect, useState } from 'react'
import { Bell } from 'lucide-react'

export function NotificationBell({ userId }: { userId: string }) {
  const [unreadCount, setUnreadCount] = useState(0)
  const supabase = createClient()

  useEffect(() => {
    // Initial count
    async function fetchUnread() {
      const { count } = await supabase
        .from('notifications')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', userId)
        .is('read_at', null)
      setUnreadCount(count ?? 0)
    }
    fetchUnread()

    // Real-time updates
    const channel = supabase
      .channel('notifications')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications',
        filter: `user_id=eq.${userId}`,
      }, () => {
        setUnreadCount(n => n + 1)
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [userId])

  return (
    <button className="relative" aria-label={`${unreadCount} unread notifications`}>
      <Bell className="h-5 w-5" />
      {unreadCount > 0 && (
        <span className="absolute -top-1 -right-1 h-4 w-4 rounded-full bg-red-500 text-xs text-white flex items-center justify-center">
          {unreadCount > 9 ? '9+' : unreadCount}
        </span>
      )}
    </button>
  )
}
```

### Marking as Read
```typescript
// Mark single notification
async function markRead(notificationId: string) {
  await supabase
    .from('notifications')
    .update({ read_at: new Date().toISOString() })
    .eq('id', notificationId)
    .eq('user_id', userId)  // security: ensure ownership
}

// Mark all as read
async function markAllRead() {
  await supabase
    .from('notifications')
    .update({ read_at: new Date().toISOString() })
    .eq('user_id', userId)
    .is('read_at', null)
}
```

### Creating Notifications (Server-Side)
Always create notifications server-side using the admin client to bypass RLS:
```typescript
// lib/notifications.ts
import { createAdminClient } from '@/lib/supabase/admin'

export async function createNotification({
  userId,
  type,
  title,
  body,
  data = {},
}: {
  userId: string
  type: string
  title: string
  body?: string
  data?: Record<string, unknown>
}) {
  const supabase = createAdminClient()
  await supabase.from('notifications').insert({
    user_id: userId,
    type,
    title,
    body,
    data,
  })
}

// Usage in a Route Handler after an invoice is paid:
await createNotification({
  userId: invoice.customer_id,
  type: 'invoice_paid',
  title: 'Invoice paid',
  body: `Invoice #${invoice.number} has been marked as paid.`,
  data: { invoiceId: invoice.id },
})
```

## Web Push Notifications

Web Push requires VAPID keys and a service worker. Only appropriate if users have opted in and need notifications while the app is NOT open.

### Setup
```bash
npm install web-push
npx web-push generate-vapid-keys
# → VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY
```

### Store Subscription
```typescript
// Client: subscribe and store the subscription
async function subscribeToPush() {
  const registration = await navigator.serviceWorker.ready
  const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY,
  })
  
  // Store on server
  await fetch('/api/push/subscribe', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(subscription),
  })
}
```

```sql
-- Store push subscriptions
CREATE TABLE push_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL UNIQUE,
  keys JSONB NOT NULL,           -- { auth, p256dh }
  created_at TIMESTAMPTZ DEFAULT now()
);
```

### Send Push Notification
```typescript
// app/api/push/send/route.ts
import webpush from 'web-push'

webpush.setVapidDetails(
  'mailto:admin@example.com',
  process.env.VAPID_PUBLIC_KEY!,
  process.env.VAPID_PRIVATE_KEY!
)

export async function POST(req: NextRequest) {
  const { userId, title, body } = await req.json()
  const supabase = createAdminClient()
  
  const { data: subscriptions } = await supabase
    .from('push_subscriptions')
    .select('endpoint, keys')
    .eq('user_id', userId)

  const results = await Promise.allSettled(
    subscriptions!.map(sub =>
      webpush.sendNotification(
        { endpoint: sub.endpoint, keys: sub.keys as { auth: string; p256dh: string } },
        JSON.stringify({ title, body })
      )
    )
  )
  
  // Remove expired subscriptions
  results.forEach((result, i) => {
    if (result.status === 'rejected' && result.reason?.statusCode === 410) {
      supabase.from('push_subscriptions').delete().eq('endpoint', subscriptions![i].endpoint)
    }
  })
  
  return NextResponse.json({ sent: results.filter(r => r.status === 'fulfilled').length })
}
```

## Email Notifications

Prefer email over push for: non-urgent notifications, detailed content, action links the user can act on later. Use Resend for email delivery — see `plugin--resend.md`.

Send from a Route Handler or Server Action, never from client code.

## Which Notification Type

| Scenario | Type |
|---|---|
| Invoice paid (immediate, in-app) | Database notification + real-time |
| New message in chat | Database notification + real-time |
| Weekly summary | Email |
| Service worker needed? User not in app | Web Push |
| Critical alert, user offline | SMS (Twilio) |
