# Notifications UI Pattern

## The Bell Icon with Badge

```typescript
// components/NotificationBell.tsx
'use client'
import { Bell } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { useNotifications } from '@/hooks/useNotifications'

export function NotificationBell() {
  const { notifications, unreadCount, markAllRead } = useNotifications()
  
  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button variant="ghost" size="icon" className="relative">
          <Bell className="h-5 w-5" />
          {unreadCount > 0 && (
            <span className="absolute -top-1 -right-1 h-5 w-5 rounded-full bg-destructive text-destructive-foreground text-xs flex items-center justify-center">
              {unreadCount > 9 ? '9+' : unreadCount}
            </span>
          )}
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-80 p-0" align="end">
        <NotificationList
          notifications={notifications}
          onMarkAllRead={markAllRead}
        />
      </PopoverContent>
    </Popover>
  )
}
```

## Notification List Component

```typescript
// components/NotificationList.tsx
function NotificationList({ notifications, onMarkAllRead }) {
  if (notifications.length === 0) {
    return (
      <div className="p-6 text-center text-muted-foreground text-sm">
        No notifications
      </div>
    )
  }
  
  return (
    <div>
      <div className="flex items-center justify-between p-3 border-b">
        <span className="font-medium text-sm">Notifications</span>
        <Button variant="ghost" size="sm" onClick={onMarkAllRead}>
          Mark all read
        </Button>
      </div>
      <ScrollArea className="max-h-[400px]">
        {notifications.map(n => (
          <NotificationItem key={n.id} notification={n} />
        ))}
      </ScrollArea>
    </div>
  )
}

function NotificationItem({ notification }) {
  const timeAgo = useTimeAgo(notification.created_at)
  
  return (
    <div className={cn(
      "flex gap-3 p-3 hover:bg-muted transition-colors",
      !notification.read_at && "bg-muted/50 border-l-2 border-l-primary"
    )}>
      <NotificationIcon type={notification.type} />
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium">{notification.title}</p>
        {notification.body && (
          <p className="text-xs text-muted-foreground truncate">{notification.body}</p>
        )}
        <p className="text-xs text-muted-foreground mt-1">{timeAgo}</p>
      </div>
    </div>
  )
}
```

## Real-Time Hook

```typescript
// hooks/useNotifications.ts
export function useNotifications() {
  const queryClient = useQueryClient()
  
  const { data: notifications = [] } = useQuery({
    queryKey: ['notifications'],
    queryFn: () => fetchNotifications(),
  })
  
  // Real-time subscription
  useEffect(() => {
    const channel = supabase
      .channel('notifications')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications',
      }, (payload) => {
        queryClient.setQueryData(['notifications'], (old: Notification[]) => 
          [payload.new as Notification, ...old]
        )
      })
      .subscribe()
    
    return () => { supabase.removeChannel(channel) }
  }, [queryClient])
  
  const unreadCount = notifications.filter(n => !n.read_at).length
  
  const markAllRead = async () => {
    await markAllNotificationsRead()
    queryClient.invalidateQueries({ queryKey: ['notifications'] })
  }
  
  return { notifications, unreadCount, markAllRead }
}
```

## Toast Notifications (Transient)

For immediate feedback that auto-dismisses — NOT the same as persistent inbox notifications:

```typescript
// Use sonner (the shadcn default)
import { toast } from 'sonner'

// Success
toast.success('Invoice marked as paid')

// Error
toast.error('Failed to save. Try again.')

// With action
toast('Invoice deleted', {
  action: {
    label: 'Undo',
    onClick: () => restoreInvoice(id),
  },
  duration: 5000,
})

// Loading state
const toastId = toast.loading('Sending email...')
await sendEmail()
toast.success('Email sent!', { id: toastId })
```

Place `<Toaster />` once in the root layout:
```typescript
// app/layout.tsx
import { Toaster } from 'sonner'
export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <Toaster position="bottom-right" richColors />
      </body>
    </html>
  )
}
```

## When to Use Each

| Scenario | Use |
|---|---|
| Action succeeded/failed | Toast |
| Something happened while away | Inbox notification |
| Requires user action | Inbox + badge |
| Background job completed | Inbox |
| Form validation error | Inline field error (not toast) |

## Notification Types Icon Map

```typescript
function NotificationIcon({ type }: { type: string }) {
  const icons = {
    'invoice_paid': <CheckCircle className="h-4 w-4 text-green-500" />,
    'invoice_overdue': <AlertCircle className="h-4 w-4 text-destructive" />,
    'new_message': <MessageSquare className="h-4 w-4 text-blue-500" />,
    'system': <Bell className="h-4 w-4 text-muted-foreground" />,
  }
  return icons[type] ?? icons['system']
}
```
