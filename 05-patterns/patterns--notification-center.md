# Pattern: Notification Center Dropdown

A bell icon in the header that opens a dropdown panel showing recent notifications grouped by date, with an unread count badge, mark-all-read, individual dismiss, and an empty state. The complexity is: badge count management, grouping logic, and keeping the panel accessible.

## Why It Matters

Notifications tucked behind a bell icon are the standard contract for async events. Users know to look there. The badge count is a pull signal that drives re-engagement. If the badge doesn't update promptly, or if dismissed notifications reappear, users stop trusting the indicator and ignore it.

## State Model

```ts
interface Notification {
  id: string;
  title: string;
  body: string;
  href?: string;
  createdAt: Date;
  readAt: Date | null;
}

interface NotificationState {
  notifications: Notification[];
  open: boolean;
}
```

## Component

```tsx
function NotificationCenter() {
  const [open, setOpen] = useState(false);
  const { notifications, markRead, markAllRead, dismiss } = useNotifications();
  const panelRef = useRef<HTMLDivElement>(null);
  const triggerId = useId();
  const panelId = useId();

  const unreadCount = notifications.filter(n => !n.readAt).length;

  // Close on outside click
  useEffect(() => {
    if (!open) return;
    const handler = (e: MouseEvent) => {
      if (!panelRef.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, [open]);

  // Mark all as read when panel is opened
  useEffect(() => {
    if (open && unreadCount > 0) markAllRead();
  }, [open]);

  const grouped = groupByDate(notifications);

  return (
    <div className="notification-center" ref={panelRef}>
      <button
        id={triggerId}
        type="button"
        aria-haspopup="dialog"
        aria-expanded={open}
        aria-controls={panelId}
        onClick={() => setOpen(o => !o)}
        className="notif-trigger"
      >
        <BellIcon aria-hidden />
        <span className="sr-only">Notifications</span>
        {unreadCount > 0 && (
          <span
            className="notif-badge"
            aria-label={`${unreadCount} unread notifications`}
          >
            {unreadCount > 99 ? '99+' : unreadCount}
          </span>
        )}
      </button>

      {open && (
        <div
          id={panelId}
          role="dialog"
          aria-label="Notifications"
          aria-modal="false"
          className="notif-panel"
        >
          <div className="notif-header">
            <h2>Notifications</h2>
            {unreadCount > 0 && (
              <button type="button" onClick={markAllRead} className="mark-all">
                Mark all read
              </button>
            )}
          </div>

          {notifications.length === 0 ? (
            <div className="notif-empty">
              <BellOffIcon aria-hidden />
              <p>You're all caught up</p>
            </div>
          ) : (
            <ul className="notif-list" role="list">
              {grouped.map(({ label, items }) => (
                <li key={label}>
                  <p className="notif-date-label" role="presentation">{label}</p>
                  <ul role="list">
                    {items.map(n => (
                      <li key={n.id} className={`notif-item ${!n.readAt ? 'notif-item--unread' : ''}`}>
                        <a href={n.href ?? '#'} onClick={() => markRead(n.id)} className="notif-content">
                          <strong>{n.title}</strong>
                          <span>{n.body}</span>
                          <time dateTime={n.createdAt.toISOString()}>
                            {formatRelative(n.createdAt)}
                          </time>
                        </a>
                        <button
                          type="button"
                          onClick={() => dismiss(n.id)}
                          aria-label={`Dismiss: ${n.title}`}
                          className="notif-dismiss"
                        >
                          ×
                        </button>
                      </li>
                    ))}
                  </ul>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}
```

## Date Grouping

```ts
function groupByDate(notifications: Notification[]) {
  const now = new Date();
  const todayStart = startOfDay(now);
  const yesterdayStart = startOfDay(subDays(now, 1));

  const groups: Record<string, Notification[]> = {};

  for (const n of notifications) {
    const d = n.createdAt;
    let label: string;
    if (d >= todayStart) label = 'Today';
    else if (d >= yesterdayStart) label = 'Yesterday';
    else label = 'Earlier';
    (groups[label] ??= []).push(n);
  }

  // Maintain display order
  return ['Today', 'Yesterday', 'Earlier']
    .filter(l => groups[l]?.length)
    .map(l => ({ label: l, items: groups[l] }));
}
```

## Unread Count Badge

Cap the badge at 99+. Three-digit counts break layouts. The badge number should update in real time via a subscription or polling:

```ts
function useNotifications() {
  const [notifications, setNotifications] = useState<Notification[]>([]);

  // Real-time via Supabase Realtime
  useEffect(() => {
    const channel = supabase
      .channel('notifications')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notifications' },
        payload => setNotifications(prev => [toNotification(payload.new), ...prev])
      )
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, []);

  function markAllRead() {
    setNotifications(prev => prev.map(n => ({ ...n, readAt: n.readAt ?? new Date() })));
    // Also persist to DB
    supabase.from('notifications').update({ read_at: new Date().toISOString() }).is('read_at', null);
  }

  function dismiss(id: string) {
    setNotifications(prev => prev.filter(n => n.id !== id));
    supabase.from('notifications').delete().eq('id', id);
  }

  return { notifications, markAllRead, dismiss };
}
```

## Mark-All-Read Timing

Mark all as read optimistically when the panel **opens** (not on close). Users expect the badge to clear as soon as they look at the notifications, not after they close the panel. If the server call fails, revert with a toast error.

## Key Rules

- **`aria-haspopup="dialog"`** on the bell button, not `aria-haspopup="menu"`.
- **Badge cap at 99+**—three-digit counts break compact headers.
- **Mark all read on open**, not on close—matches user mental model.
- **Group by Today / Yesterday / Earlier**—relative labels are more scannable than dates.
- **`aria-modal="false"`** on the panel—it's not a blocking dialog; background is still interactive.
- **Optimistic dismiss**—remove from local state immediately, sync to server in background.
- **Empty state with icon**—"You're all caught up" is more reassuring than a blank panel.
- **Real-time updates**—poll or subscribe so the badge reflects new notifications without a page refresh.
