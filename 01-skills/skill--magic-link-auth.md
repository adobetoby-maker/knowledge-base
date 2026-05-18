# Skill: Magic Link Authentication

## What It Is

Passwordless authentication via email. User enters email → receives link with signed token → clicks link → logged in. No password storage. Works with Supabase Auth built-in. Good for low-friction B2C auth; not good for enterprise (users can't share tokens safely, no central revocation without extra infra).

## Supabase Magic Links

Supabase handles the full flow natively. Configure in Supabase Dashboard → Authentication → Email Templates.

### Send Magic Link

```ts
// app/auth/magic-link/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'
import { z } from 'zod'

const schema = z.object({ email: z.string().email() })

export async function POST(request: NextRequest) {
  const body = await request.json()
  const result = schema.safeParse(body)
  if (!result.success) {
    return NextResponse.json({ error: 'Invalid email' }, { status: 400 })
  }

  const supabase = createRouteHandlerClient({ cookies })

  const { error } = await supabase.auth.signInWithOtp({
    email: result.data.email,
    options: {
      emailRedirectTo: `${process.env.NEXT_PUBLIC_SITE_URL}/auth/callback`,
      shouldCreateUser: true,  // Create account if doesn't exist
    },
  })

  if (error) {
    console.error('Magic link error:', error)
    // Don't expose whether email exists (prevents user enumeration)
    return NextResponse.json({ success: true })
  }

  return NextResponse.json({ success: true })
}
```

Always return `{ success: true }` regardless of whether the email exists — don't let attackers enumerate accounts.

### Auth Callback Handler

```ts
// app/auth/callback/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'

export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')
  const next = searchParams.get('next') ?? '/dashboard'

  if (code) {
    const supabase = createRouteHandlerClient({ cookies })
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`)
    }
  }

  // Redirect to error page on failure
  return NextResponse.redirect(`${origin}/auth/error`)
}
```

The `code` in the URL is a PKCE code — `exchangeCodeForSession` exchanges it for a session and sets the session cookie.

### Client-Side Form

```tsx
'use client'
import { useState } from 'react'

export function MagicLinkForm() {
  const [email, setEmail] = useState('')
  const [sent, setSent] = useState(false)
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)

    await fetch('/auth/magic-link', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email }),
    })

    setSent(true)
    setLoading(false)
  }

  if (sent) {
    return (
      <div className="text-center">
        <p className="text-lg font-medium">Check your email</p>
        <p className="text-gray-600 mt-2">
          We sent a sign-in link to <strong>{email}</strong>.
          The link expires in 1 hour.
        </p>
        <button
          onClick={() => setSent(false)}
          className="mt-4 text-blue-600 underline"
        >
          Use a different email
        </button>
      </div>
    )
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="you@example.com"
        required
        autoComplete="email"
        className="w-full border rounded px-3 py-2"
      />
      <button
        type="submit"
        disabled={loading}
        className="w-full bg-blue-600 text-white py-2 rounded"
      >
        {loading ? 'Sending...' : 'Send sign-in link'}
      </button>
    </form>
  )
}
```

## Custom Token Magic Links (Without Supabase Auth)

For admin panels or invite flows where you own the token:

```ts
// lib/magic-link.ts
import { SignJWT, jwtVerify } from 'jose'

const SECRET = new TextEncoder().encode(process.env.MAGIC_LINK_SECRET!)

export async function createMagicToken(email: string, expiresIn = '1h') {
  return new SignJWT({ email, type: 'magic' })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime(expiresIn)
    .sign(SECRET)
}

export async function verifyMagicToken(token: string): Promise<string | null> {
  try {
    const { payload } = await jwtVerify(token, SECRET)
    if (payload.type !== 'magic') return null
    return payload.email as string
  } catch {
    return null  // Expired or invalid
  }
}
```

```ts
// Send link
const token = await createMagicToken(email)
const link = `${process.env.SITE_URL}/auth/magic?token=${token}`
await sendEmail({ to: email, subject: 'Sign in', text: `Click to sign in: ${link}` })

// Verify on click
const email = await verifyMagicToken(searchParams.get('token') ?? '')
if (!email) return redirect('/auth/error')
// Create session for email
```

## Rate Limiting

Magic link endpoints must be rate-limited — attackers can spam them to flood inboxes:

```ts
import { Ratelimit } from '@upstash/ratelimit'

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(3, '1 h'),  // 3 magic links per hour per email
})

const { success } = await ratelimit.limit(email)
if (!success) {
  return NextResponse.json({ error: 'Too many requests' }, { status: 429 })
}
```

## Token Expiry and One-Time Use

Supabase magic links expire in 1 hour by default (configurable in Dashboard). For custom tokens, invalidate after first use:

```ts
// Store used tokens in DB with short TTL
await supabase.from('used_magic_tokens').insert({ token_hash: hash(token) })
// Check at verification time
```

Or use the JWT `jti` (JWT ID) claim + a bloom filter / Redis set for one-time use enforcement.
