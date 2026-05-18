# Plugin: PostHog

## What It Is

PostHog is an open-source analytics platform: event tracking, session replay, feature flags, A/B tests, funnels, and user paths. Self-hostable or cloud. Works with Next.js App Router including Server Components.

## Installation

```bash
npm install posthog-js posthog-node
```

## Provider Setup (Next.js App Router)

```tsx
// app/providers/posthog.tsx
'use client'
import posthog from 'posthog-js'
import { PostHogProvider } from 'posthog-js/react'
import { useEffect } from 'react'

export function PHProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY!, {
      api_host: process.env.NEXT_PUBLIC_POSTHOG_HOST ?? 'https://app.posthog.com',
      capture_pageview: false,  // Manual pageview control for App Router
      capture_pageleave: true,
    })
  }, [])

  return <PostHogProvider client={posthog}>{children}</PostHogProvider>
}
```

```tsx
// app/layout.tsx
import { PHProvider } from './providers/posthog'

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        <PHProvider>{children}</PHProvider>
      </body>
    </html>
  )
}
```

## Pageview Tracking (App Router)

```tsx
// app/providers/pageview.tsx
'use client'
import { usePathname, useSearchParams } from 'next/navigation'
import { usePostHog } from 'posthog-js/react'
import { useEffect } from 'react'

export function PostHogPageview() {
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const posthog = usePostHog()

  useEffect(() => {
    if (pathname && posthog) {
      let url = window.origin + pathname
      if (searchParams.toString()) {
        url += `?${searchParams.toString()}`
      }
      posthog.capture('$pageview', { $current_url: url })
    }
  }, [pathname, searchParams, posthog])

  return null
}
```

App Router doesn't trigger `capture_pageview` automatically — always add `PostHogPageview` inside a Suspense boundary.

## Identifying Users

```tsx
// After login — link anonymous events to the user
posthog.identify(user.id, {
  email: user.email,
  name: user.full_name,
  plan: user.plan_tier,
})

// On logout — reset to anonymous
posthog.reset()
```

Call `identify` once after auth. Anonymous events before login are merged with the identified user automatically (via `$anon_distinct_id`).

## Event Capture

```tsx
// Client-side
import { usePostHog } from 'posthog-js/react'

function PayButton({ invoiceId }: { invoiceId: string }) {
  const posthog = usePostHog()

  return (
    <button
      onClick={() => {
        posthog.capture('invoice_paid', {
          invoice_id: invoiceId,
          source: 'portal',
        })
      }}
    >
      Pay Now
    </button>
  )
}
```

```ts
// Server-side (Route Handlers, Server Actions)
import { PostHog } from 'posthog-node'

const serverPosthog = new PostHog(process.env.POSTHOG_KEY!, {
  host: process.env.POSTHOG_HOST ?? 'https://app.posthog.com',
  flushAt: 1,  // Flush immediately (serverless functions don't stay alive)
  flushInterval: 0,
})

// In a Route Handler
await serverPosthog.capture({
  distinctId: userId,
  event: 'invoice_sent',
  properties: { invoice_id: invoiceId, total_cents: totalCents },
})
await serverPosthog.shutdown()  // Required in serverless
```

## Feature Flags

```tsx
// Client-side
import { useFeatureFlagEnabled } from 'posthog-js/react'

function Dashboard() {
  const showNewUI = useFeatureFlagEnabled('new-dashboard-ui')

  return showNewUI ? <NewDashboard /> : <OldDashboard />
}
```

```ts
// Server-side (with user context)
const flagEnabled = await serverPosthog.isFeatureEnabled(
  'new-checkout',
  userId,
)
```

Feature flags need `distinctId` to evaluate rollout percentages. Server-side flag evaluation makes one API call per check — cache the result.

## Privacy and Compliance

```ts
posthog.init(key, {
  persistence: 'memory',  // No cookies/localStorage (GDPR strict mode)
  respect_dnt: true,      // Honor Do Not Track header
  sanitize_properties: (props) => {
    delete props['$ip']  // Remove IP if required
    return props
  },
})
```

## Session Replay

Session replay is enabled by default when you call `posthog.init`. To mask sensitive fields:

```ts
posthog.init(key, {
  session_recording: {
    maskAllInputs: true,                  // Mask all inputs by default
    maskInputFn: (text, element) => {
      if (element?.getAttribute('data-posthog-mask')) return '***'
      return text
    },
  },
})
```

Add `data-posthog-mask` attribute to any element containing PII (credit card fields, SSNs, etc.).

## Environment Variables

```
NEXT_PUBLIC_POSTHOG_KEY=phc_xxx
NEXT_PUBLIC_POSTHOG_HOST=https://app.posthog.com
POSTHOG_KEY=phc_xxx      # Server-side (same key, no NEXT_PUBLIC_)
POSTHOG_HOST=https://app.posthog.com
```
