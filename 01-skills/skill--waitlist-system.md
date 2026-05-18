# Skill: Waitlist System

## Overview

Collect emails before launch, send confirmation, track referrals, and manage waitlist position. Standard SaaS pre-launch mechanism.

## Database Schema

```sql
CREATE TABLE waitlist (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         TEXT UNIQUE NOT NULL,
  referral_code TEXT UNIQUE NOT NULL DEFAULT substring(gen_random_uuid()::text, 1, 8),
  referred_by   TEXT REFERENCES waitlist(referral_code),  -- referral code of who referred them
  referral_count INTEGER NOT NULL DEFAULT 0,
  position      INTEGER GENERATED ALWAYS AS IDENTITY,     -- insertion order
  approved      BOOLEAN NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX ON waitlist (referral_code);
CREATE INDEX ON waitlist (email);
```

## Signup Endpoint

```ts
// app/api/waitlist/route.ts
import { z } from 'zod'
import { sendWaitlistConfirmation } from '@/lib/email'

const schema = z.object({
  email: z.string().email(),
  referralCode: z.string().length(8).optional(),
})

export async function POST(req: Request) {
  const body = await req.json()
  const parsed = schema.safeParse(body)
  if (!parsed.success) {
    return Response.json({ error: 'Invalid email' }, { status: 400 })
  }

  const { email, referralCode } = parsed.data

  // Verify referral code exists (if provided)
  if (referralCode) {
    const { data: referrer } = await supabase
      .from('waitlist')
      .select('id')
      .eq('referral_code', referralCode)
      .single()

    if (!referrer) {
      return Response.json({ error: 'Invalid referral code' }, { status: 400 })
    }
  }

  // Insert (ignore duplicate)
  const { data, error } = await supabase
    .from('waitlist')
    .insert({ email, referred_by: referralCode ?? null })
    .select('referral_code, position')
    .single()

  if (error) {
    if (error.code === '23505') {
      // Already on waitlist — return their info
      const { data: existing } = await supabase
        .from('waitlist')
        .select('referral_code, position, referral_count')
        .eq('email', email)
        .single()
      return Response.json({ alreadyJoined: true, ...existing })
    }
    return Response.json({ error: 'Failed to join' }, { status: 500 })
  }

  // Update referral count
  if (referralCode) {
    await supabase.rpc('increment_referral_count', { p_code: referralCode })
  }

  // Send confirmation email
  await sendWaitlistConfirmation({
    to: email,
    referralCode: data.referral_code,
    position: data.position,
    referralLink: `${process.env.NEXT_PUBLIC_BASE_URL}?ref=${data.referral_code}`,
  })

  return Response.json({ success: true, position: data.position, referralCode: data.referral_code })
}
```

```sql
CREATE OR REPLACE FUNCTION increment_referral_count(p_code TEXT)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE waitlist SET referral_count = referral_count + 1 WHERE referral_code = p_code;
$$;
```

## Waitlist Position Component

```tsx
'use client'
import { useState } from 'react'

export function WaitlistForm({ referralCode }: { referralCode?: string }) {
  const [email, setEmail] = useState('')
  const [result, setResult] = useState<{
    position?: number
    referralCode?: string
    referralCount?: number
    alreadyJoined?: boolean
  } | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    setError('')

    const res = await fetch('/api/waitlist', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, referralCode }),
    })
    const data = await res.json()
    setLoading(false)

    if (!res.ok) {
      setError(data.error)
      return
    }
    setResult(data)
  }

  if (result) {
    return (
      <div className="text-center space-y-4">
        <p className="text-2xl font-bold">
          {result.alreadyJoined ? 'You\'re already on the list!' : 'You\'re on the list!'}
        </p>
        <p className="text-gray-600">You're #{result.position} in line.</p>
        <div className="bg-gray-50 rounded-xl p-6">
          <p className="text-sm font-medium text-gray-700 mb-2">
            Skip the line — share your referral link:
          </p>
          <p className="text-sm text-gray-500 mb-3">
            {result.referralCount ?? 0} people have joined using your link
          </p>
          <input
            readOnly
            value={`${window.location.origin}?ref=${result.referralCode}`}
            className="w-full px-3 py-2 border rounded-lg text-sm bg-white"
            onClick={(e) => (e.target as HTMLInputElement).select()}
          />
        </div>
      </div>
    )
  }

  return (
    <form onSubmit={handleSubmit} className="flex gap-3">
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Enter your email"
        required
        className="flex-1 px-4 py-3 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
      <button
        type="submit"
        disabled={loading}
        className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 font-medium"
      >
        {loading ? 'Joining...' : 'Join Waitlist'}
      </button>
      {error && <p className="text-red-600 text-sm mt-2">{error}</p>}
    </form>
  )
}
```

## Admin: Approve Users

```ts
// app/api/admin/waitlist/approve/route.ts
export async function POST(req: Request) {
  const { ids } = await req.json()

  await supabase.from('waitlist').update({ approved: true }).in('id', ids)

  // Send approval emails
  const { data: approved } = await supabase
    .from('waitlist')
    .select('email')
    .in('id', ids)

  await Promise.all(
    (approved ?? []).map((u) => sendApprovalEmail({ to: u.email }))
  )

  return Response.json({ approved: ids.length })
}
```

## Referral Leaderboard

```ts
// Top referrers query
const { data: leaders } = await supabase
  .from('waitlist')
  .select('email, referral_count, position')
  .order('referral_count', { ascending: false })
  .limit(10)
```

## Rate Limiting

Apply rate limiting to the signup endpoint — 5 requests per IP per hour minimum. Without it, a competitor or bot can flood the waitlist with fake emails that distort your metrics and exhaust your email quota.

See `skill--rate-limiting.md` for the Upstash/Redis implementation.
