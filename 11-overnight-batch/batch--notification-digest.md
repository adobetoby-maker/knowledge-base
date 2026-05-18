# Batch: Notification Digest

## Overview

Daily or weekly email digest summarizing unread notifications. Reduces notification overload while keeping users informed. Scheduled batch job queries pending notifications, groups them by user, and sends one email per user.

## Database Schema

```sql
CREATE TABLE notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL,    -- 'comment', 'mention', 'like', 'system'
  title       TEXT NOT NULL,
  body        TEXT,
  data        JSONB DEFAULT '{}',
  read_at     TIMESTAMPTZ,
  emailed_at  TIMESTAMPTZ,      -- Set when included in a digest
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX ON notifications (user_id, read_at, emailed_at, created_at);

-- User preferences
CREATE TABLE notification_preferences (
  user_id       UUID PRIMARY KEY REFERENCES auth.users(id),
  digest_enabled BOOLEAN NOT NULL DEFAULT true,
  digest_freq   TEXT NOT NULL DEFAULT 'daily',  -- 'daily', 'weekly', 'never'
  digest_hour   INTEGER NOT NULL DEFAULT 8,     -- UTC hour to send
  updated_at    TIMESTAMPTZ DEFAULT now()
);
```

## Digest Job Script

```ts
// scripts/send-notification-digest.ts
import { format, subHours, subDays, subWeeks } from 'date-fns'
import { sendDigestEmail } from '@/lib/email/digest'

async function sendNotificationDigests(freq: 'daily' | 'weekly') {
  const lookbackPeriod = freq === 'daily' ? subDays(new Date(), 1) : subWeeks(new Date(), 1)

  // Get users with pending digest-eligible notifications
  const { data: usersWithNotifications } = await adminSupabase.rpc('get_digest_candidates', {
    p_freq: freq,
    p_since: lookbackPeriod.toISOString(),
  })

  console.log(`Sending ${freq} digest to ${usersWithNotifications?.length ?? 0} users`)

  let sent = 0
  let failed = 0

  for (const { user_id, email, notification_count } of usersWithNotifications ?? []) {
    try {
      // Fetch the actual notifications for this user
      const { data: notifications } = await adminSupabase
        .from('notifications')
        .select('*')
        .eq('user_id', user_id)
        .is('emailed_at', null)
        .is('read_at', null)
        .gte('created_at', lookbackPeriod.toISOString())
        .order('created_at', { ascending: false })
        .limit(20)

      if (!notifications?.length) continue

      // Group by type
      const grouped = groupByType(notifications)

      await sendDigestEmail({
        to: email,
        grouped,
        totalCount: notification_count,
        period: freq,
      })

      // Mark all as emailed
      await adminSupabase
        .from('notifications')
        .update({ emailed_at: new Date().toISOString() })
        .in('id', notifications.map((n) => n.id))

      sent++
    } catch (err) {
      console.error(`Failed to send digest to ${email}:`, err)
      failed++
    }
  }

  console.log(`Digest complete: ${sent} sent, ${failed} failed`)
}

function groupByType(notifications: Notification[]): Record<string, Notification[]> {
  return notifications.reduce((acc, n) => {
    acc[n.type] = [...(acc[n.type] ?? []), n]
    return acc
  }, {} as Record<string, Notification[]>)
}
```

## Database Function for Digest Candidates

```sql
CREATE OR REPLACE FUNCTION get_digest_candidates(p_freq TEXT, p_since TIMESTAMPTZ)
RETURNS TABLE(user_id UUID, email TEXT, notification_count BIGINT)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    n.user_id,
    u.email,
    COUNT(*) as notification_count
  FROM notifications n
  JOIN auth.users u ON u.id = n.user_id
  JOIN notification_preferences np ON np.user_id = n.user_id
  WHERE
    np.digest_enabled = true
    AND np.digest_freq = p_freq
    AND n.emailed_at IS NULL
    AND n.read_at IS NULL
    AND n.created_at >= p_since
  GROUP BY n.user_id, u.email
  HAVING COUNT(*) > 0
$$;
```

## Digest Email Template

```ts
// lib/email/digest.ts
import { render } from '@react-email/render'
import DigestEmail from '@/emails/DigestEmail'
import { resend } from './client'

interface DigestEmailData {
  to: string
  grouped: Record<string, Notification[]>
  totalCount: number
  period: 'daily' | 'weekly'
}

export async function sendDigestEmail({ to, grouped, totalCount, period }: DigestEmailData) {
  const html = render(DigestEmail({ grouped, totalCount, period }))

  await resend.emails.send({
    from: 'noreply@yourapp.com',
    to,
    subject: `You have ${totalCount} unread notification${totalCount > 1 ? 's' : ''} — ${period === 'daily' ? 'Today' : 'This Week'}`,
    html,
  })
}
```

## Scheduling

```yaml
# .github/workflows/notification-digest.yml
on:
  schedule:
    - cron: '0 8 * * *'   # Daily digest at 8am UTC
    - cron: '0 8 * * 1'   # Weekly digest every Monday 8am UTC

jobs:
  digest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - name: Daily digest
        if: github.event.schedule == '0 8 * * *'
        run: npx tsx scripts/send-notification-digest.ts daily
        env:
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
          RESEND_API_KEY: ${{ secrets.RESEND_API_KEY }}
      - name: Weekly digest
        if: github.event.schedule == '0 8 * * 1'
        run: npx tsx scripts/send-notification-digest.ts weekly
        env:
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
          RESEND_API_KEY: ${{ secrets.RESEND_API_KEY }}
```

## Unsubscribe

Every digest email must have a one-click unsubscribe link:

```ts
// Generate signed unsubscribe URL
const token = await signJWT({ userId, purpose: 'unsubscribe-digest' }, '30d')
const unsubUrl = `${BASE_URL}/notifications/unsubscribe?token=${token}`

// Unsubscribe route
export async function GET(req: Request) {
  const token = new URL(req.url).searchParams.get('token')
  const { userId } = await verifyJWT(token)
  await adminSupabase
    .from('notification_preferences')
    .upsert({ user_id: userId, digest_enabled: false })
  return new Response('<p>Unsubscribed.</p>', { headers: { 'Content-Type': 'text/html' } })
}
```

CAN-SPAM and GDPR both require a functional unsubscribe mechanism in every bulk email. One-click is the standard.
