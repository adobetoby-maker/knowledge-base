# Skill: Referral System

## Overview

Track who referred whom, credit referrers when referrals convert, and display referral stats. Standard growth mechanism: share link → friend signs up → referrer gets reward.

## Database Schema

```sql
CREATE TABLE referrals (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id  UUID NOT NULL REFERENCES auth.users(id),
  referee_id   UUID REFERENCES auth.users(id),  -- NULL until they sign up
  code         TEXT UNIQUE NOT NULL,             -- short referral code
  email        TEXT,                             -- invited by email (optional)
  status       TEXT NOT NULL DEFAULT 'pending',  -- pending / signed_up / converted / rewarded
  reward_type  TEXT,                             -- 'credit', 'discount', 'upgrade'
  reward_value INTEGER,                          -- cents or units
  created_at   TIMESTAMPTZ DEFAULT now(),
  converted_at TIMESTAMPTZ
);

CREATE INDEX ON referrals (referrer_id);
CREATE INDEX ON referrals (code);
CREATE INDEX ON referrals (referee_id);
```

## Generating a Referral Code

```ts
// lib/referrals.ts
import { customAlphabet } from 'nanoid'

const generateCode = customAlphabet('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 8)

export async function getOrCreateReferralCode(userId: string): Promise<string> {
  // Check if user already has a code
  const { data: existing } = await adminSupabase
    .from('referrals')
    .select('code')
    .eq('referrer_id', userId)
    .is('referee_id', null)  // The "master" code row has no referee
    .limit(1)
    .single()

  if (existing) return existing.code

  // Create a new code
  const code = generateCode()
  await adminSupabase.from('referrals').insert({
    referrer_id: userId,
    code,
    status: 'active',  // Special status for master referral rows
  })

  return code
}
```

## Tracking Referral Clicks

Store the referral code in a cookie when a visitor lands on the site via a referral link:

```ts
// app/api/ref/route.ts
export async function GET(req: Request) {
  const code = new URL(req.url).searchParams.get('code')
  if (!code) return NextResponse.redirect('/')

  const response = NextResponse.redirect('/')
  response.cookies.set('ref_code', code, {
    maxAge: 30 * 24 * 60 * 60,  // 30 days
    httpOnly: true,
    sameSite: 'lax',
  })
  return response
}
```

Share link format: `https://yourapp.com/api/ref?code=ABC12345`

## Crediting the Referral on Signup

```ts
// app/api/auth/signup/route.ts (or in onAuthStateChange callback)
export async function POST(req: Request) {
  const { email, password } = await req.json()
  const refCode = req.cookies.get('ref_code')?.value

  const { data: { user }, error } = await supabase.auth.signUp({ email, password })
  if (error || !user) throw error

  if (refCode) {
    await creditReferral(refCode, user.id)
  }

  return Response.json({ success: true })
}

async function creditReferral(code: string, refereeId: string) {
  // Find the referral code
  const { data: referral } = await adminSupabase
    .from('referrals')
    .select('id, referrer_id')
    .eq('code', code)
    .single()

  if (!referral) return  // Invalid code — ignore silently

  // Prevent self-referral
  if (referral.referrer_id === refereeId) return

  // Prevent double-credit (user already used a referral)
  const { data: existing } = await adminSupabase
    .from('referrals')
    .select('id')
    .eq('referee_id', refereeId)
    .single()

  if (existing) return

  // Record the referral
  await adminSupabase.from('referrals').insert({
    referrer_id: referral.referrer_id,
    referee_id: refereeId,
    code,
    status: 'signed_up',
  })

  // Award referrer immediately (or wait for conversion — depends on business model)
  await awardReferralCredit(referral.referrer_id)
}
```

## Reward Timing: Signup vs. Conversion

**Award on signup**: Simpler. Risk: users sign up with fake emails to farm rewards.

**Award on conversion** (first purchase, subscription, etc.): Safer. Requires tracking referral through the funnel:

```ts
// When user makes first purchase
async function handleFirstPurchase(userId: string, orderId: string) {
  const { data: referral } = await adminSupabase
    .from('referrals')
    .select('id, referrer_id')
    .eq('referee_id', userId)
    .eq('status', 'signed_up')
    .single()

  if (referral) {
    await adminSupabase
      .from('referrals')
      .update({ status: 'converted', converted_at: new Date().toISOString() })
      .eq('id', referral.id)

    await awardReferralCredit(referral.referrer_id)
  }
}
```

## Referral Dashboard Component

```tsx
export async function ReferralDashboard({ userId }: { userId: string }) {
  const code = await getOrCreateReferralCode(userId)
  const referralLink = `${process.env.NEXT_PUBLIC_BASE_URL}/api/ref?code=${code}`

  const { data: stats } = await adminSupabase
    .from('referrals')
    .select('status')
    .eq('referrer_id', userId)
    .not('referee_id', 'is', null)

  const signedUp = stats?.filter((r) => r.status !== 'pending').length ?? 0
  const converted = stats?.filter((r) => r.status === 'converted' || r.status === 'rewarded').length ?? 0

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-blue-50 rounded-xl p-4">
          <p className="text-2xl font-bold text-blue-900">{signedUp}</p>
          <p className="text-sm text-blue-600">Friends signed up</p>
        </div>
        <div className="bg-green-50 rounded-xl p-4">
          <p className="text-2xl font-bold text-green-900">{converted}</p>
          <p className="text-sm text-green-600">Friends converted</p>
        </div>
      </div>

      <div>
        <p className="text-sm font-medium text-gray-700 mb-2">Your referral link</p>
        <div className="flex gap-2">
          <input readOnly value={referralLink} className="flex-1 px-3 py-2 border rounded-lg text-sm bg-gray-50"
            onClick={(e) => (e.target as HTMLInputElement).select()} />
          <CopyButton text={referralLink} />
        </div>
      </div>
    </div>
  )
}
```
