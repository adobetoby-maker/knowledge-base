# Skill: Email Verification

## Overview

Verify a user's email address after signup. Send a time-limited token, confirm ownership on click, then mark the account as verified. Distinct from password reset (different flow) and newsletter confirmation (different table). Block key actions for unverified users, but don't make the entire app unusable.

## Schema

```sql
ALTER TABLE users ADD COLUMN email_verified_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN email_verification_token TEXT;
ALTER TABLE users ADD COLUMN email_verification_sent_at TIMESTAMPTZ;
```

Or separate table (cleaner for multiple pending verifications):

```sql
CREATE TABLE email_verifications (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  email      TEXT NOT NULL,         -- capture email at time of sending
  token      TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at    TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## Send Verification Email

```ts
export async function sendVerificationEmail(userId: string): Promise<void> {
  const user = await db.query.users.findFirst({ where: eq(users.id, userId) })
  if (!user) throw new Error('User not found')
  if (user.emailVerifiedAt) return  // Already verified

  // Rate limit: don't spam
  if (user.emailVerificationSentAt) {
    const cooldown = 60 * 1000  // 1 minute
    if (Date.now() - new Date(user.emailVerificationSentAt).getTime() < cooldown) {
      throw new Error('Please wait before requesting another verification email.')
    }
  }

  const token = crypto.randomBytes(32).toString('hex')
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000)  // 24 hours

  await db.update(users).set({
    emailVerificationToken: token,
    emailVerificationSentAt: new Date(),
  }).where(eq(users.id, userId))

  const verifyUrl = `${process.env.NEXT_PUBLIC_SITE_URL}/verify-email?token=${token}`

  await sendEmail({
    to: user.email,
    subject: 'Verify your email address',
    template: 'email-verification',
    data: { name: user.name, verifyUrl, expiresIn: '24 hours' },
  })
}
```

## Verify Token Route

```ts
// app/verify-email/route.ts
export async function GET(req: Request) {
  const token = new URL(req.url).searchParams.get('token')
  if (!token) return redirectWithError('invalid')

  const user = await db.query.users.findFirst({
    where: eq(users.emailVerificationToken, token),
  })

  if (!user) return redirectWithError('invalid')
  if (user.emailVerifiedAt) return redirectSuccess('already-verified')

  // Check expiry (stored as sent_at + 24h)
  const sentAt = user.emailVerificationSentAt
  if (!sentAt || Date.now() - new Date(sentAt).getTime() > 24 * 60 * 60 * 1000) {
    return redirectWithError('expired')
  }

  await db.update(users).set({
    emailVerifiedAt: new Date(),
    emailVerificationToken: null,
    emailVerificationSentAt: null,
  }).where(eq(users.id, user.id))

  // Log the user in and redirect to dashboard
  const session = await createSession(user.id)
  return redirectWithSession('/dashboard?verified=true', session)
}

function redirectWithError(reason: string) {
  return Response.redirect(`${process.env.NEXT_PUBLIC_SITE_URL}/verify-email?error=${reason}`)
}
```

## Verification Banner (UI)

Show in app for unverified users:

```tsx
function VerificationBanner({ user }: { user: User }) {
  const [sending, setSending] = useState(false)
  const [sent, setSent] = useState(false)

  if (user.emailVerifiedAt) return null

  const resend = async () => {
    setSending(true)
    await fetch('/api/auth/resend-verification', { method: 'POST' })
    setSending(false)
    setSent(true)
  }

  return (
    <div className="bg-amber-50 border-b border-amber-200 px-4 py-3 flex items-center gap-4 text-sm">
      <span>Please verify your email address (<strong>{user.email}</strong>).</span>
      {sent ? (
        <span className="text-green-700">Verification email sent!</span>
      ) : (
        <button onClick={resend} disabled={sending} className="underline hover:no-underline">
          {sending ? 'Sending…' : 'Resend email'}
        </button>
      )}
    </div>
  )
}
```

## Gate Sensitive Actions

```ts
// middleware or route guard
function requireVerifiedEmail(user: User) {
  if (!user.emailVerifiedAt) {
    throw new AppError('Please verify your email before continuing.', 403)
  }
}

// Block billing, invites, API key creation — not reading
export async function POST(req: Request) {
  const user = await requireAuth(req)
  requireVerifiedEmail(user)
  // ... proceed
}
```

## Key Rules

- Send verification immediately after signup — don't wait for the user to ask.
- Gate only sensitive actions (billing, invites, publishing) for unverified users — don't lock them out of the entire app.
- 1-minute cooldown on resend prevents abuse; 24-hour token expiry is standard.
- Token must be invalidated after use — set `emailVerificationToken: null` on success.
- Supabase Auth includes built-in email verification — use `supabase.auth.signUp({ email, password })` with `emailRedirectTo` for managed flows.
