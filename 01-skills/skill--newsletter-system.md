# Skill: Newsletter System

## Overview

Build a newsletter subscription system: subscribe/unsubscribe flow, double opt-in confirmation, subscriber management, and broadcast sending. Use Resend or Postmark for transactional email; ConvertKit or Loops for large lists. For lists under 5,000 subscribers, Resend Broadcasts is sufficient.

## Schema

```sql
CREATE TABLE newsletter_subscribers (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email            TEXT NOT NULL UNIQUE,
  name             TEXT,
  status           TEXT NOT NULL DEFAULT 'pending',  -- pending | confirmed | unsubscribed
  confirmation_token TEXT UNIQUE,
  confirmed_at     TIMESTAMPTZ,
  unsubscribed_at  TIMESTAMPTZ,
  source           TEXT,           -- 'homepage', 'blog-post', 'checkout'
  metadata         JSONB NOT NULL DEFAULT '{}',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX newsletter_status_idx ON newsletter_subscribers(status, created_at DESC);
```

## Subscribe Flow

```ts
// actions/newsletter.ts
export async function subscribe(email: string, source: string): Promise<{ success: boolean; message: string }> {
  // Normalize
  const normalizedEmail = email.toLowerCase().trim()

  // Check for existing subscriber
  const existing = await db.query.newsletterSubscribers.findFirst({
    where: eq(newsletterSubscribers.email, normalizedEmail),
  })

  if (existing?.status === 'confirmed') {
    return { success: true, message: 'You are already subscribed!' }
  }

  if (existing?.status === 'unsubscribed') {
    // Re-subscribe: reset status and send new confirmation
    const token = generateToken()
    await db.update(newsletterSubscribers)
      .set({ status: 'pending', confirmationToken: token, unsubscribedAt: null })
      .where(eq(newsletterSubscribers.id, existing.id))
    await sendConfirmationEmail(normalizedEmail, token)
    return { success: true, message: 'Check your email to confirm.' }
  }

  if (existing?.status === 'pending') {
    // Resend confirmation
    await sendConfirmationEmail(normalizedEmail, existing.confirmationToken!)
    return { success: true, message: 'Confirmation email resent.' }
  }

  // New subscriber
  const token = generateToken()
  await db.insert(newsletterSubscribers).values({
    email: normalizedEmail,
    status: 'pending',
    confirmationToken: token,
    source,
  })

  await sendConfirmationEmail(normalizedEmail, token)
  return { success: true, message: 'Check your email to confirm your subscription.' }
}

function generateToken(): string {
  return crypto.randomBytes(32).toString('hex')
}
```

## Confirmation Email

```ts
async function sendConfirmationEmail(email: string, token: string) {
  const confirmUrl = `${process.env.NEXT_PUBLIC_SITE_URL}/newsletter/confirm?token=${token}`

  await resend.emails.send({
    from: 'Newsletter <newsletter@example.com>',
    to: email,
    subject: 'Confirm your subscription',
    html: `
      <p>Click the link below to confirm your newsletter subscription:</p>
      <p><a href="${confirmUrl}">Confirm subscription</a></p>
      <p>This link expires in 24 hours. If you didn't subscribe, ignore this email.</p>
    `,
  })
}
```

## Confirmation Route

```ts
// app/newsletter/confirm/route.ts
export async function GET(req: Request) {
  const { searchParams } = new URL(req.url)
  const token = searchParams.get('token')

  if (!token) {
    return Response.redirect(`${process.env.NEXT_PUBLIC_SITE_URL}/newsletter?error=invalid`)
  }

  const subscriber = await db.query.newsletterSubscribers.findFirst({
    where: eq(newsletterSubscribers.confirmationToken, token),
  })

  if (!subscriber || subscriber.status !== 'pending') {
    return Response.redirect(`${process.env.NEXT_PUBLIC_SITE_URL}/newsletter?error=expired`)
  }

  // Confirm
  await db.update(newsletterSubscribers)
    .set({
      status: 'confirmed',
      confirmationToken: null,
      confirmedAt: new Date(),
    })
    .where(eq(newsletterSubscribers.id, subscriber.id))

  // Send welcome email
  await sendWelcomeEmail(subscriber.email)

  return Response.redirect(`${process.env.NEXT_PUBLIC_SITE_URL}/newsletter?confirmed=true`)
}
```

## Unsubscribe

```ts
// app/newsletter/unsubscribe/route.ts
export async function GET(req: Request) {
  const { searchParams } = new URL(req.url)
  const email = searchParams.get('email')
  const token = searchParams.get('token')

  // Verify HMAC token: HMAC(secret, email)
  const expected = createHmac('sha256', process.env.UNSUBSCRIBE_SECRET!)
    .update(email ?? '')
    .digest('hex')

  if (token !== expected) {
    return new Response('Invalid unsubscribe link', { status: 400 })
  }

  await db.update(newsletterSubscribers)
    .set({ status: 'unsubscribed', unsubscribedAt: new Date() })
    .where(eq(newsletterSubscribers.email, email!))

  return Response.redirect(`${process.env.NEXT_PUBLIC_SITE_URL}/newsletter?unsubscribed=true`)
}
```

## Broadcast Sending

```ts
async function sendBroadcast(subject: string, htmlContent: string) {
  const subscribers = await db.query.newsletterSubscribers.findMany({
    where: eq(newsletterSubscribers.status, 'confirmed'),
    columns: { email: true },
  })

  const BATCH_SIZE = 50
  for (let i = 0; i < subscribers.length; i += BATCH_SIZE) {
    const batch = subscribers.slice(i, i + BATCH_SIZE)

    await resend.batch.send(batch.map(s => ({
      from: 'Newsletter <newsletter@example.com>',
      to: s.email,
      subject,
      html: htmlContent + generateUnsubscribeFooter(s.email),
    })))

    // Brief pause between batches to avoid rate limits
    if (i + BATCH_SIZE < subscribers.length) {
      await new Promise(r => setTimeout(r, 1000))
    }
  }
}

function generateUnsubscribeFooter(email: string): string {
  const token = createHmac('sha256', process.env.UNSUBSCRIBE_SECRET!).update(email).digest('hex')
  const url = `${process.env.NEXT_PUBLIC_SITE_URL}/newsletter/unsubscribe?email=${encodeURIComponent(email)}&token=${token}`
  return `<p style="color:#999;font-size:12px;">
    <a href="${url}">Unsubscribe</a> from this newsletter.
  </p>`
}
```

## Key Rules

- Double opt-in (confirmation email) is required by GDPR and CAN-SPAM — never auto-confirm subscriptions.
- Unsubscribe links must use HMAC tokens (not just email in URL) — otherwise anyone can unsubscribe anyone.
- Include an unsubscribe footer in every email — required by CAN-SPAM law.
- Token expiry: check `created_at < now() - interval '24 hours'` for confirmation tokens.
- Never hard-delete unsubscribed records — maintain a suppression list to prevent re-subscribing from other sources.
