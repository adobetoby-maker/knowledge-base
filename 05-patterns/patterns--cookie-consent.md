# Pattern: GDPR Cookie Consent Banner

## What This Solves

GDPR (EU), CCPA (California), and similar laws require explicit, informed consent before setting non-essential cookies or activating analytics/marketing scripts. The legal risk is real: fines up to 4% of global annual revenue for GDPR violations. The UX challenge is doing this without blocking the entire page or burying users in legalese.

## Cookie Categories

Define three tiers — never flatten them into a single "Accept all" without a granular option:

1. **Essential** — strictly necessary for the site to function (session cookies, CSRF tokens, auth). Cannot be disabled. Do not ask consent for these.
2. **Analytics** — usage data (page views, session recordings, conversion funnels). Examples: GA4, Posthog, Hotjar. Require opt-in in EU; opt-out acceptable in US.
3. **Marketing** — ad targeting, cross-site tracking. Examples: Meta Pixel, Google Ads. Require opt-in. Most users decline these.

## Consent Storage

Persist consent to `localStorage` (not a cookie — ironic but correct). Cookies can be set by servers; localStorage can only be read client-side and doesn't need its own consent.

```ts
// lib/consent.ts
export type ConsentState = {
  analytics: boolean
  marketing: boolean
  timestamp: number
}

export function getConsent(): ConsentState | null {
  const raw = localStorage.getItem('cookie_consent')
  if (!raw) return null
  return JSON.parse(raw) as ConsentState
}

export function setConsent(state: Omit<ConsentState, 'timestamp'>) {
  localStorage.setItem('cookie_consent', JSON.stringify({
    ...state,
    timestamp: Date.now(),
  }))
}
```

Re-ask consent after 12 months (GDPR guidance) by checking `timestamp`.

## Conditional Script Loading

Never load analytics or marketing scripts until consent is given. Load them dynamically after consent:

```tsx
// components/ConsentScriptLoader.tsx
'use client'
import { useEffect } from 'react'
import { getConsent } from '@/lib/consent'

export function ConsentScriptLoader() {
  useEffect(() => {
    const consent = getConsent()
    if (!consent) return

    if (consent.analytics) {
      // Dynamically inject GA4
      const script = document.createElement('script')
      script.src = `https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXX`
      script.async = true
      document.head.appendChild(script)
      window.gtag?.('consent', 'update', { analytics_storage: 'granted' })
    }

    if (consent.marketing) {
      // Meta Pixel, etc.
      window.fbq?.('consent', 'grant')
    }
  }, [])

  return null
}
```

Load this at the root layout. Scripts that are already initialized cannot be "un-loaded" — this is why you must not inject them before consent.

## The Banner Component

```tsx
// components/CookieBanner.tsx
'use client'
import { useState, useEffect } from 'react'
import { getConsent, setConsent } from '@/lib/consent'

export function CookieBanner() {
  const [visible, setVisible] = useState(false)
  const [showPrefs, setShowPrefs] = useState(false)
  const [analytics, setAnalytics] = useState(false)
  const [marketing, setMarketing] = useState(false)

  useEffect(() => {
    const c = getConsent()
    if (!c || Date.now() - c.timestamp > 365 * 24 * 60 * 60 * 1000) {
      setVisible(true)
    }
  }, [])

  if (!visible) return null

  function acceptAll() {
    setConsent({ analytics: true, marketing: true })
    setVisible(false)
    window.location.reload() // reload to trigger script injection
  }

  function rejectAll() {
    setConsent({ analytics: false, marketing: false })
    setVisible(false)
  }

  function savePrefs() {
    setConsent({ analytics, marketing })
    setVisible(false)
    if (analytics || marketing) window.location.reload()
  }

  return (
    <div
      role="dialog"
      aria-label="Cookie consent"
      className="fixed bottom-4 left-4 right-4 md:left-auto md:max-w-md z-50 bg-background border rounded-xl shadow-xl p-5 space-y-4"
    >
      {!showPrefs ? (
        <>
          <p className="text-sm text-muted-foreground">
            We use cookies to improve your experience.{' '}
            <a href="/privacy" className="underline">Privacy policy</a>
          </p>
          <div className="flex flex-wrap gap-2">
            <button onClick={acceptAll} className="px-4 py-2 bg-primary text-primary-foreground rounded-md text-sm">
              Accept all
            </button>
            <button onClick={rejectAll} className="px-4 py-2 border rounded-md text-sm">
              Reject all
            </button>
            <button onClick={() => setShowPrefs(true)} className="text-sm underline text-muted-foreground">
              Manage preferences
            </button>
          </div>
        </>
      ) : (
        <>
          <h3 className="font-medium text-sm">Cookie preferences</h3>
          <label className="flex items-center gap-3 text-sm">
            <input type="checkbox" checked disabled /> Essential (always on)
          </label>
          <label className="flex items-center gap-3 text-sm">
            <input type="checkbox" checked={analytics} onChange={e => setAnalytics(e.target.checked)} />
            Analytics
          </label>
          <label className="flex items-center gap-3 text-sm">
            <input type="checkbox" checked={marketing} onChange={e => setMarketing(e.target.checked)} />
            Marketing
          </label>
          <button onClick={savePrefs} className="px-4 py-2 bg-primary text-primary-foreground rounded-md text-sm w-full">
            Save preferences
          </button>
        </>
      )}
    </div>
  )
}
```

## Key Rules

- Never load analytics or marketing scripts before consent is confirmed
- Essential cookies do not require consent — never show a toggle for them
- Always provide both "Accept all" and "Reject all" as equal-prominence buttons — dark patterns (hiding Reject) are illegal under GDPR
- Store consent in localStorage with a timestamp; re-request after 12 months
- Reload the page after granting consent so script injection happens cleanly via `ConsentScriptLoader`
- Position the banner to avoid obscuring primary content (bottom of screen, not full-screen takeover)
- Include a link to the privacy policy on the banner itself
