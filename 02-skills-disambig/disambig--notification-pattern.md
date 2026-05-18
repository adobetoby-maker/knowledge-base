# Disambig: Notification Pattern

## Decision Tree

**Does the notification need to persist after the user navigates away?**
- No → Toast (ephemeral, action-triggered)
- Yes → In-app notification inbox (stored, queryable)

**Is it triggered by a user action in the same session?**
- Yes → Toast (sonner)
- No (background process, another user) → Notification inbox + possibly push notification

**Does the user need to take action on it?**
- No → Toast (informational only)
- Yes → Notification inbox with action buttons

## Toast (Sonner)

Use for: form submit success, mutation confirmation, copy to clipboard, minor errors.

```typescript
import { toast } from 'sonner'

// After mutation success:
toast.success('Invoice created')
toast.error('Failed to send email')
toast.loading('Sending invoice...', { id: 'send' })
toast.success('Invoice sent!', { id: 'send' })  // replaces loading

// With action:
toast('Invoice deleted', {
  action: { label: 'Undo', onClick: () => restoreInvoice(id) },
  duration: 5000,
})
```

## In-App Notification Inbox

Use for: invoice paid notifications, new customer submissions, background job completion, events from other users.

Requires: `notifications` table in Supabase, `NotificationBell` component, realtime subscription.

See: `patterns--notifications-ui.md`

## Email Notification

Use for: events the user needs to see even when not logged in — invoice due date reminders, new client inquiry, payment received.

Requires: Resend (or SMTP), email template, Server Action or cron trigger.

Not for: instant UI feedback (latency is seconds, not milliseconds).

## Push Notification (Browser/Mobile)

Use for: urgent alerts the user needs while the app isn't open — service completion, appointment reminder.

Requires: service worker, Web Push API or a service like OneSignal. High complexity, only worth it for genuinely time-sensitive notifications.

## Combining Patterns

For an invoice-paid event:
1. Store in `notifications` table (persistent, queryable)
2. Show in `NotificationBell` badge (in-app)
3. Send email (reaches user even if not logged in)
4. Optionally: toast if the user happens to be on the page when it fires (via realtime)

For a form submit success:
1. Toast only — no persistence needed, user sees it immediately
