# Pattern: Notification Dot / Badge

## Overview

Notification dots (red badges) indicate unread items: messages, alerts, tasks. The key design decisions: show exact count vs dot-only, where to position the badge, max count display ("99+"), and how to clear the notification state when items are read.

## Badge Component

```tsx
interface BadgeProps {
  count: number
  max?: number      // Show "99+" when count exceeds max
  dot?: boolean     // Dot only — no count
  className?: string
}

export function NotificationBadge({ count, max = 99, dot = false, className }: BadgeProps) {
  if (count <= 0) return null

  const label = dot ? '' : count > max ? `${max}+` : String(count)

  return (
    <span
      className={cn(
        'inline-flex items-center justify-center bg-red-500 text-white font-medium rounded-full',
        dot
          ? 'w-2 h-2'
          : label.length === 1
            ? 'w-5 h-5 text-xs'
            : 'h-5 min-w-[20px] px-1 text-xs',
        className
      )}
      aria-label={dot ? 'Notifications' : `${count} notification${count !== 1 ? 's' : ''}`}
    >
      {label}
    </span>
  )
}
```

## Nav Icon with Badge

```tsx
function NavIconWithBadge({ icon: Icon, label, count, href }: NavIconProps) {
  return (
    <Link href={href} className="relative inline-flex items-center p-2">
      <Icon className="w-6 h-6" />
      {count > 0 && (
        <NotificationBadge
          count={count}
          className="absolute -top-0.5 -right-0.5"
        />
      )}
      <span className="sr-only">{label} {count > 0 ? `(${count} unread)` : ''}</span>
    </Link>
  )
}
```

`absolute -top-0.5 -right-0.5` positions the badge in the top-right corner of the icon. The parent must be `relative`.

## Fetching Unread Count

```ts
// Efficient: count query, not full fetch
async function getUnreadCount(userId: string): Promise<number> {
  const result = await db.select({ count: count() })
    .from(notifications)
    .where(and(eq(notifications.userId, userId), isNull(notifications.readAt)))
  return result[0].count
}
```

## Real-Time Count Update

```tsx
function useUnreadCount(userId: string) {
  const [unreadCount, setUnreadCount] = useState(0)

  // Initial fetch
  useEffect(() => {
    getUnreadCount(userId).then(setUnreadCount)
  }, [userId])

  // Real-time updates
  useEffect(() => {
    const channel = supabase
      .channel(`notifications:${userId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications',
        filter: `user_id=eq.${userId}`,
      }, () => {
        setUnreadCount(prev => prev + 1)
      })
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'notifications',
        filter: `user_id=eq.${userId}`,
      }, (payload) => {
        // Mark as read event
        if (payload.new.read_at && !payload.old.read_at) {
          setUnreadCount(prev => Math.max(0, prev - 1))
        }
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [userId])

  return unreadCount
}
```

## Mark as Read on View

```ts
// Mark notifications read when the user opens the notification panel
async function markAllRead(userId: string) {
  await db.update(notifications)
    .set({ readAt: new Date() })
    .where(and(eq(notifications.userId, userId), isNull(notifications.readAt)))
}

// Or mark a specific notification
async function markRead(notificationId: string, userId: string) {
  await db.update(notifications)
    .set({ readAt: new Date() })
    .where(and(eq(notifications.id, notificationId), eq(notifications.userId, userId)))
}
```

## Favicon Badge (Browser Tab)

```ts
// Update favicon with badge count (PWA-style)
function updateFaviconBadge(count: number) {
  if (!('setAppBadge' in navigator)) return  // Not supported
  if (count > 0) {
    navigator.setAppBadge(count).catch(() => {})
  } else {
    navigator.clearAppBadge().catch(() => {})
  }
}
```

## Key Rules

- `Math.max(0, prev - 1)` when decrementing count — prevents negative counts if events arrive out of order.
- `count: count()` in the SQL query is far cheaper than fetching all rows — never pull full notification records just to count them.
- The badge aria-label must state the count for screen readers — a red dot without text is invisible to assistive technology.
- Use `dot` (no count) for privacy-sensitive contexts where showing exact counts leaks information.
- Clear the badge immediately when the user opens the notification panel (optimistic clear) — don't wait for the server roundtrip.
