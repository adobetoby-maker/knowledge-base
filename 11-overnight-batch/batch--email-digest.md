# Batch Job: Email Digest

## Overview

Send digest emails summarizing activity over a period (daily, weekly). Common digests: "Here's what happened this week", "5 new messages in your inbox", "Your monthly usage report". Run as a scheduled job, not per-event — digest means batching many events into one email.

## Digest Architecture

```
Events occur throughout the day
         ↓
Events stored in DB (not emailed immediately)
         ↓
Cron at 8AM: aggregate events per user
         ↓
Render one email per user with all events
         ↓
Send via Resend / Postmark
         ↓
Mark events as digested
```

## Activity Aggregation Query

```ts
async function getUserDigestData(userId: string, since: Date): Promise<DigestData> {
  const [comments, mentions, orders, followerGrowth] = await Promise.all([
    // New comments on user's posts
    db.execute(sql`
      SELECT c.body, c.created_at, p.title as post_title, p.slug as post_slug
      FROM comments c
      JOIN posts p ON c.post_id = p.id
      WHERE p.author_id = ${userId}
        AND c.created_at >= ${since}
        AND c.author_id != ${userId}
      ORDER BY c.created_at DESC
      LIMIT 10
    `),

    // Mentions of this user
    db.execute(sql`
      SELECT * FROM mentions
      WHERE mentioned_user_id = ${userId}
        AND created_at >= ${since}
      ORDER BY created_at DESC
      LIMIT 5
    `),

    // Order count for sellers
    db.execute(sql`
      SELECT COUNT(*) as count, SUM(total_cents) as revenue
      FROM orders
      WHERE seller_id = ${userId}
        AND created_at >= ${since}
        AND status = 'completed'
    `),

    // New followers
    db.execute(sql`
      SELECT COUNT(*) as count
      FROM follows
      WHERE followee_id = ${userId}
        AND created_at >= ${since}
    `),
  ])

  return {
    commentCount: comments.length,
    comments: comments.slice(0, 5),
    mentionCount: mentions.length,
    orderCount: Number(orders[0]?.count ?? 0),
    revenueCents: Number(orders[0]?.revenue ?? 0),
    newFollowers: Number(followerGrowth[0]?.count ?? 0),
  }
}
```

## Sending the Digest

```ts
async function sendWeeklyDigests(): Promise<void> {
  const since = subDays(startOfDay(new Date()), 7)

  // Only users who have opted in and have activity
  const recipients = await db.execute(sql`
    SELECT DISTINCT u.id, u.email, u.name
    FROM users u
    WHERE u.digest_enabled = true
      AND u.email_verified_at IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM events e
        WHERE e.target_id = u.id
          AND e.created_at >= ${since}
      )
  `)

  logger.info({ count: recipients.length }, 'Sending weekly digests')

  for (const user of recipients) {
    try {
      const data = await getUserDigestData(user.id, since)

      // Skip if nothing worth sending
      if (data.commentCount + data.mentionCount + data.orderCount + data.newFollowers === 0) continue

      await resend.emails.send({
        from: 'Weekly Digest <digest@example.com>',
        to: user.email,
        subject: `Your weekly activity summary`,
        react: WeeklyDigestEmail({ user, data, since }),
      })
    } catch (err) {
      logger.error({ userId: user.id, err }, 'Failed to send digest')
    }
  }
}
```

## Email Template (React Email)

```tsx
// emails/WeeklyDigestEmail.tsx
import { Html, Head, Body, Container, Text, Link, Hr } from '@react-email/components'

export function WeeklyDigestEmail({ user, data, since }: DigestEmailProps) {
  return (
    <Html>
      <Head />
      <Body style={{ fontFamily: 'sans-serif', background: '#f8fafc' }}>
        <Container style={{ maxWidth: 600, margin: '0 auto', padding: 32 }}>
          <Text>Hi {user.name},</Text>
          <Text>Here's what happened on your account this week:</Text>

          {data.commentCount > 0 && (
            <>
              <Text style={{ fontWeight: 700 }}>
                💬 {data.commentCount} new comment{data.commentCount !== 1 ? 's' : ''}
              </Text>
              {data.comments.map((c, i) => (
                <Text key={i} style={{ color: '#64748b', fontSize: 14 }}>
                  On <Link href={`${BASE_URL}/posts/${c.postSlug}`}>{c.postTitle}</Link>
                </Text>
              ))}
            </>
          )}

          {data.newFollowers > 0 && (
            <Text>👥 {data.newFollowers} new follower{data.newFollowers !== 1 ? 's' : ''}</Text>
          )}

          {data.orderCount > 0 && (
            <Text>
              🛍️ {data.orderCount} order{data.orderCount !== 1 ? 's' : ''} — 
              ${(data.revenueCents / 100).toFixed(2)} earned
            </Text>
          )}

          <Hr />
          <Text style={{ color: '#94a3b8', fontSize: 12 }}>
            <Link href={`${BASE_URL}/settings/notifications`}>Manage digest settings</Link>
            {' · '}
            <Link href={generateUnsubscribeUrl(user.email)}>Unsubscribe</Link>
          </Text>
        </Container>
      </Body>
    </Html>
  )
}
```

## Digest Preferences

```sql
ALTER TABLE users ADD COLUMN digest_enabled BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN digest_frequency TEXT NOT NULL DEFAULT 'weekly'
  CHECK (digest_frequency IN ('daily', 'weekly', 'never'));
ALTER TABLE users ADD COLUMN digest_day_of_week INT DEFAULT 1;  -- 0=Sun, 1=Mon
```

## Key Rules

- Only send digests to users who have recent activity — empty digests train users to ignore them.
- Include an unsubscribe link and a "manage preferences" link — required by CAN-SPAM.
- Batch send in small groups with delays — sending to thousands simultaneously triggers spam filters.
- Track open rates: if < 15%, revisit the content or frequency.
- Mark events as "digested" to avoid including them in the next digest.
