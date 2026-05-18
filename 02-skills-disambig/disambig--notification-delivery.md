# Disambiguation: Notification Delivery Methods

## Decision Tree

```
Is the user currently active in the browser?
  YES → In-app toast or notification bell
  NO  → Continue below

Does the notification require immediate attention?
  YES (urgent, time-sensitive) → SMS (Twilio) or push notification
  NO  → Email (async delivery acceptable)

Is the user's device/browser known and consented?
  YES (web push registered) → Web push notification
  NO  → Email or SMS

Is this a transactional notification (receipt, verification, password reset)?
  YES → Email (user expects it in inbox)
  NO  → Check urgency above

Is this a marketing/promotional notification?
  YES → Email with unsubscribe or push with opt-in
  CAREFUL → SMS marketing has strict regulations (TCPA)
```

## Comparison Table

| Method | When user sees it | Cost | Requires opt-in |
|--------|------------------|------|-----------------|
| In-app toast | Only while on site | Free | No |
| Email | When they check email | ~$0.001 per email | No (transactional) |
| SMS | Immediately | ~$0.01-0.05 per SMS | No (transactional) |
| Web push | Immediately (if device on) | Free | Yes (browser prompt) |
| In-app notification bell | Next time they log in | Free | No |

## In-App Toast (react-hot-toast or Sonner)

```tsx
import { toast } from 'sonner'

// Success
toast.success('Invoice sent successfully')

// Error
toast.error('Payment failed — please try again')

// Promise (shows loading/success/error automatically)
toast.promise(sendInvoice(id), {
  loading: 'Sending invoice...',
  success: 'Invoice sent',
  error: 'Failed to send invoice',
})
```

## Email (Transactional)

Use Resend or SendGrid. Best for: receipts, confirmations, password resets, digest notifications.

```ts
// Resend
import { Resend } from 'resend'
const resend = new Resend(process.env.RESEND_API_KEY)

await resend.emails.send({
  from: 'noreply@jrsautorepair.com',
  to: customer.email,
  subject: `Invoice ${invoice.number} from JR's Auto Repair`,
  react: <InvoiceEmailTemplate invoice={invoice} />,
})
```

Transactional email (receipt, receipt) doesn't require opt-in under CAN-SPAM. Marketing email requires unsubscribe.

## SMS (Twilio)

Use for: appointment reminders, payment confirmations, urgent alerts. Higher cost — reserve for high-value notifications.

```ts
import twilio from 'twilio'

const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN)

await client.messages.create({
  body: `Your appointment is confirmed for tomorrow at 9am. JR's Auto Repair (208) 595-2101`,
  from: process.env.TWILIO_FROM,
  to: customer.phone,
})
```

SMS regulations: TCPA requires express written consent for marketing SMS. Transactional SMS (appointment confirmation, receipt) generally doesn't require opt-in, but consult legal for your jurisdiction.

## Web Push Notifications

Best for: re-engagement when users are away from your site but have the browser open or device on.

Requires:
1. Browser permission prompt accepted by user
2. Service worker registered
3. VAPID keys for auth

```ts
// Request permission
const permission = await Notification.requestPermission()
if (permission === 'granted') {
  const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY,
  })
  await savePushSubscription(subscription)
}

// Send from server (web-push library)
import webpush from 'web-push'

await webpush.sendNotification(
  subscription,
  JSON.stringify({
    title: 'New invoice ready',
    body: 'Invoice #1042 is ready for payment',
    icon: '/icon-192.png',
    url: '/invoices/1042',
  })
)
```

Opt-in rates are typically 5-15%. Don't push non-essential notifications — users will revoke permission.

## Notification Bell (In-App)

For notifications the user sees on their next login:

```sql
CREATE TABLE notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  type text NOT NULL,
  title text NOT NULL,
  body text,
  read_at timestamptz,
  created_at timestamptz DEFAULT now()
);
```

Poll or use Supabase Realtime for the unread count badge. Mark as read when the user clicks.

## Multi-Channel Strategy

For critical notifications (appointment in 2 hours):
1. SMS first (immediate)
2. Email as follow-up (confirmation record)
3. In-app notification (when user next visits)

Don't send all channels simultaneously for the same event — users find it annoying. Use a preference center to let users choose their preferred channel.
