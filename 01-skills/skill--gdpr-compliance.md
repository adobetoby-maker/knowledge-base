# Skill: GDPR Compliance

## Overview

GDPR (EU General Data Protection Regulation) requires: lawful basis for processing, user rights (access, deletion, portability), consent for marketing, data minimization, and breach notification. This guide covers the implementation requirements for SaaS applications.

## Core Obligations

**Only collect what you need**: If you don't need birthdate, don't collect it. If you collect email but never use it, delete it.

**Lawful basis for processing**:
- Contract: processing needed to fulfill service (you must process data to send invoices)
- Consent: explicit opt-in for marketing emails, analytics tracking
- Legitimate interest: fraud prevention, security

## Cookie Consent

```tsx
// components/CookieConsent.tsx
'use client'
import { useState, useEffect } from 'react'

type ConsentState = {
  analytics: boolean
  marketing: boolean
  given: boolean
}

export function CookieConsent() {
  const [consent, setConsent] = useState<ConsentState | null>(null)
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    const stored = localStorage.getItem('cookie-consent')
    if (stored) {
      setConsent(JSON.parse(stored))
    } else {
      setVisible(true)
    }
  }, [])

  function acceptAll() {
    const c: ConsentState = { analytics: true, marketing: true, given: true }
    localStorage.setItem('cookie-consent', JSON.stringify(c))
    setConsent(c)
    setVisible(false)
    // Initialize analytics
    initAnalytics()
  }

  function acceptEssential() {
    const c: ConsentState = { analytics: false, marketing: false, given: true }
    localStorage.setItem('cookie-consent', JSON.stringify(c))
    setConsent(c)
    setVisible(false)
  }

  if (!visible) return null

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 bg-white border-t p-4 shadow-lg">
      <div className="max-w-4xl mx-auto flex items-center justify-between gap-4">
        <p className="text-sm text-gray-700">
          We use cookies to improve your experience. Essential cookies are required for the service to function.
          {' '}
          <a href="/privacy" className="underline">Privacy Policy</a>
        </p>
        <div className="flex gap-2 shrink-0">
          <button onClick={acceptEssential} className="px-3 py-1.5 text-sm border rounded hover:bg-gray-50">
            Essential only
          </button>
          <button onClick={acceptAll} className="px-3 py-1.5 text-sm bg-blue-600 text-white rounded hover:bg-blue-700">
            Accept all
          </button>
        </div>
      </div>
    </div>
  )
}
```

## Right to Access (Data Export)

Users have the right to see all data you hold about them:

```ts
// app/api/account/export/route.ts
export async function GET(req: Request) {
  const user = await requireAuth()

  const [profile, invoices, payments, activities] = await Promise.all([
    db.query.users.findFirst({ where: eq(users.id, user.id) }),
    db.query.invoices.findMany({ where: eq(invoices.userId, user.id) }),
    db.query.payments.findMany({ where: eq(payments.userId, user.id) }),
    db.query.auditLog.findMany({ where: eq(auditLog.userId, user.id), limit: 1000 }),
  ])

  const exportData = {
    exportedAt: new Date().toISOString(),
    profile: {
      // Exclude password hash!
      id: profile?.id,
      email: profile?.email,
      name: profile?.name,
      createdAt: profile?.createdAt,
    },
    invoices,
    payments,
    activityLog: activities,
  }

  return new Response(JSON.stringify(exportData, null, 2), {
    headers: {
      'Content-Type': 'application/json',
      'Content-Disposition': `attachment; filename="my-data-export-${Date.now()}.json"`,
    },
  })
}
```

## Right to Erasure (Account Deletion)

```ts
// app/api/account/delete/route.ts
export async function DELETE(req: Request) {
  const user = await requireAuth()
  const { confirmation } = await req.json()

  if (confirmation !== 'DELETE MY ACCOUNT') {
    return Response.json({ error: 'Confirmation text does not match' }, { status: 400 })
  }

  // Hard delete or anonymize?
  // Hard delete: actually remove rows
  // Anonymize: keep rows but replace PII with "deleted_user" placeholder
  // Anonymize is better for: audit trails, financial records you're legally required to keep

  // Anonymize approach:
  await db.update(users).set({
    email: `deleted-${user.id}@deleted.invalid`,
    name: 'Deleted User',
    phone: null,
    deletedAt: new Date(),
  }).where(eq(users.id, user.id))

  // Keep invoice records (legal requirement for 7 years in most countries)
  // But anonymize customer name in invoices
  await db.update(invoices).set({
    customerName: 'Deleted User',
    customerEmail: `deleted-${user.id}@deleted.invalid`,
    customerPhone: null,
  }).where(eq(invoices.userId, user.id))

  // Cancel Stripe subscription
  if (user.stripeSubscriptionId) {
    await stripe.subscriptions.cancel(user.stripeSubscriptionId)
  }

  // Invalidate sessions
  await supabase.auth.admin.deleteUser(user.id)

  return Response.json({ success: true })
}
```

## Marketing Consent Tracking

```sql
CREATE TABLE marketing_consents (
  user_id    UUID PRIMARY KEY REFERENCES users(id),
  email_ok   BOOLEAN NOT NULL DEFAULT false,
  sms_ok     BOOLEAN NOT NULL DEFAULT false,
  given_at   TIMESTAMPTZ,
  source     TEXT,  -- Where consent was given: signup, settings, campaign
  ip_address INET,  -- Required for GDPR audit trail
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

Always store: when consent was given, what was consented to, where it was given, and the IP. This is your audit trail if challenged.

## Privacy Policy Requirements

A GDPR-compliant privacy policy must include:
- What data you collect and why (lawful basis)
- How long you keep data
- Who you share it with (analytics providers, payment processors)
- User rights and how to exercise them
- Contact information for data controller
- Data Protection Officer contact (if required by your scale)
