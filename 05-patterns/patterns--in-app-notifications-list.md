# Pattern: In-App Notification List

## Overview
In-app notifications replace the need to send an email for every minor event. The unread badge count drives re-engagement (users check the bell to clear the badge). Grouping by day reduces cognitive load on notifications-heavy apps — a flat list of 50 items in reverse chronological order is hard to scan. Real-time delivery via SSE or WebSocket eliminates the need for polling and prevents the notification count from being stale.

## Implementation

### Notification Data Model
```tsx
interface AppNotification {
  id: string
  type: 'mention' | 'assignment' | 'comment' | 'status_change' | 'system'
  title: string
  description: string
  timestamp: string        // ISO 8601
  read: boolean
  ctaLabel?: string
  ctaHref?: string
  iconUrl?: string
}
```

### Grouping by Day
```tsx
function groupByDay(
  notifications: AppNotification[]
): { label: string; items: AppNotification[] }[] {
  const groups = new Map<string, AppNotification[]>()

  for (const n of notifications) {
    const date = new Date(n.timestamp)
    const today = new Date()
    const yesterday = new Date(today)
    yesterday.setDate(yesterday.getDate() - 1)

    let label: string
    if (isSameDay(date, today)) label = 'Today'
    else if (isSameDay(date, yesterday)) label = 'Yesterday'
    else label = date.toLocaleDateString('en-US', { month: 'long', day: 'numeric' })

    if (!groups.has(label)) groups.set(label, [])
    groups.get(label)!.push(n)
  }

  return [...groups.entries()].map(([label, items]) => ({ label, items }))
}

function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
}
```

### Real-Time via SSE
```tsx
function useNotificationStream(userId: string) {
  const queryClient = useQueryClient()

  useEffect(() => {
    const source = new EventSource(`/api/notifications/stream?userId=${userId}`)

    source.addEventListener('notification', (e) => {
      const notification: AppNotification = JSON.parse(e.data)
      // Prepend to cached list
      queryClient.setQueryData<AppNotification[]>(
        ['notifications', userId],
        (prev = []) => [notification, ...prev]
      )
    })

    source.addEventListener('read', (e) => {
      const { id } = JSON.parse(e.data)
      queryClient.setQueryData<AppNotification[]>(
        ['notifications', userId],
        (prev = []) => prev.map((n) => (n.id === id ? { ...n, read: true } : n))
      )
    })

    return () => source.close()
  }, [userId, queryClient])
}
```

### Notification List Component
```tsx
function NotificationList({
  notifications,
  onMarkRead,
  onMarkAllRead,
  onDismiss,
  onDismissAll,
  hasMore,
  onLoadMore,
}: NotificationListProps) {
  const unreadCount = notifications.filter((n) => !n.read).length
  const groups = groupByDay(notifications)

  return (
    <div
      role="region"
      aria-label={`Notifications${unreadCount > 0 ? `, ${unreadCount} unread` : ''}`}
    >
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b">
        <h2 className="font-semibold">
          Notifications
          {unreadCount > 0 && (
            <span className="ml-2 bg-blue-600 text-white text-xs rounded-full px-1.5 py-0.5">
              {unreadCount}
            </span>
          )}
        </h2>
        {unreadCount > 0 && (
          <button
            type="button"
            onClick={onMarkAllRead}
            className="text-sm text-blue-600 hover:underline"
          >
            Mark all read
          </button>
        )}
      </div>

      {/* Grouped list */}
      <div className="overflow-y-auto max-h-96">
        {groups.length === 0 ? (
          <p className="text-sm text-gray-500 text-center py-12">
            No notifications yet.
          </p>
        ) : (
          groups.map((group) => (
            <div key={group.label}>
              <div className="sticky top-0 bg-gray-50 px-4 py-1 text-xs font-medium text-gray-500 border-b">
                {group.label}
              </div>
              {group.items.map((n) => (
                <NotificationItem
                  key={n.id}
                  notification={n}
                  onMarkRead={() => onMarkRead(n.id)}
                  onDismiss={() => onDismiss(n.id)}
                />
              ))}
            </div>
          ))
        )}

        {/* Infinite scroll trigger */}
        {hasMore && (
          <button
            type="button"
            onClick={onLoadMore}
            className="w-full py-3 text-sm text-blue-600 hover:bg-gray-50"
          >
            Load more
          </button>
        )}
      </div>
    </div>
  )
}
```

### Notification Item
```tsx
function NotificationItem({
  notification: n,
  onMarkRead,
  onDismiss,
}: {
  notification: AppNotification
  onMarkRead: () => void
  onDismiss: () => void
}) {
  const NotifIcon = NOTIFICATION_ICONS[n.type]

  return (
    <div
      className={[
        'flex gap-3 px-4 py-3 hover:bg-gray-50 border-b transition-colors',
        !n.read ? 'bg-blue-50' : '',
      ].join(' ')}
      aria-live="off"
    >
      {/* Type icon */}
      <div className="flex-shrink-0 mt-0.5">
        <NotifIcon className="w-5 h-5 text-gray-500" />
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <p className={`text-sm ${!n.read ? 'font-semibold' : 'font-medium'}`}>
          {n.title}
        </p>
        <p className="text-xs text-gray-500 mt-0.5 line-clamp-2">{n.description}</p>
        <div className="flex items-center gap-3 mt-1">
          <time className="text-xs text-gray-400" dateTime={n.timestamp}>
            {formatRelativeTime(n.timestamp)}
          </time>
          {n.ctaHref && (
            <a
              href={n.ctaHref}
              onClick={onMarkRead}
              className="text-xs text-blue-600 hover:underline"
            >
              {n.ctaLabel ?? 'View'}
            </a>
          )}
        </div>
      </div>

      {/* Actions */}
      <div className="flex flex-col gap-1 flex-shrink-0">
        {!n.read && (
          <button
            type="button"
            onClick={onMarkRead}
            aria-label="Mark as read"
            className="w-2 h-2 rounded-full bg-blue-500 hover:bg-blue-700 mt-1.5"
          />
        )}
        <button
          type="button"
          onClick={onDismiss}
          aria-label="Dismiss notification"
          className="text-gray-300 hover:text-gray-500 text-xs"
        >
          ×
        </button>
      </div>
    </div>
  )
}
```

## Key Rules
- Unread badge count reflects server state — sync it on SSE events, not just local optimistic updates
- Group by day (Today / Yesterday / date) — flat reverse-chronological lists become unusable above ~20 items
- Mark individual and all-at-once as read — individual for precision, all-at-once for clearing after checking
- Use SSE for real-time delivery — WebSocket is heavier and not needed for unidirectional notification push
- Infinite scroll with a "Load more" button — auto-infinite scroll in a bounded panel (max-height container) fights the user's scroll intent
- CTA link opens the related resource; clicking it also marks the notification as read
- `aria-live="off"` on individual items — items that are already visible should not announce to screen readers on every render; only new items should announce
- The unread dot (blue circle) doubles as a "mark read" button to save space — ensure it has an `aria-label`
