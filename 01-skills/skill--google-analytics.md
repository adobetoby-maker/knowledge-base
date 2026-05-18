# Google Analytics Integration

## GA4 with Next.js (Strategy: lazyOnload)

Load analytics after the page is interactive — never in the `<head>` with the critical path:

```typescript
// app/layout.tsx
import Script from 'next/script'

const GA_ID = process.env.NEXT_PUBLIC_GA_ID  // 'G-XXXXXXXXXX'

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        {children}
        
        {GA_ID && (
          <>
            <Script
              src={`https://www.googletagmanager.com/gtag/js?id=${GA_ID}`}
              strategy="lazyOnload"
            />
            <Script id="google-analytics" strategy="lazyOnload">
              {`
                window.dataLayer = window.dataLayer || [];
                function gtag(){dataLayer.push(arguments);}
                gtag('js', new Date());
                gtag('config', '${GA_ID}', {
                  page_path: window.location.pathname,
                });
              `}
            </Script>
          </>
        )}
      </body>
    </html>
  )
}
```

`strategy="lazyOnload"` defers until after the page is fully interactive. Never use `strategy="beforeInteractive"` for analytics.

## Page View Tracking in Next.js App Router

The App Router doesn't fire traditional page load events on navigation — use the `usePathname` hook to track route changes:

```typescript
// components/AnalyticsProvider.tsx
'use client'
import { usePathname, useSearchParams } from 'next/navigation'
import { useEffect } from 'react'

export function AnalyticsProvider({ gaId }: { gaId: string }) {
  const pathname = usePathname()
  const searchParams = useSearchParams()
  
  useEffect(() => {
    if (!window.gtag) return
    const url = pathname + (searchParams.toString() ? `?${searchParams}` : '')
    window.gtag('config', gaId, { page_path: url })
  }, [pathname, searchParams, gaId])
  
  return null
}

// Wrap in Suspense because useSearchParams requires it
// In layout.tsx:
<Suspense fallback={null}>
  <AnalyticsProvider gaId={GA_ID} />
</Suspense>
```

## Custom Event Tracking

```typescript
// lib/analytics.ts
declare global {
  interface Window {
    gtag: (...args: unknown[]) => void
  }
}

export function trackEvent(
  action: string,
  category: string,
  label?: string,
  value?: number
) {
  if (!window.gtag) return
  
  window.gtag('event', action, {
    event_category: category,
    event_label: label,
    value,
  })
}

// Usage in components:
trackEvent('click', 'CTA', 'hero-book-appointment')
trackEvent('submit', 'form', 'contact-form')
trackEvent('view', 'service', 'oil-change')
```

## Conversion Tracking

For contact form submissions, appointment bookings — these are the most important GA4 events for a local business:

```typescript
// app/contact/actions.ts
'use server'
export async function submitContactForm(formData: FormData) {
  // Save to DB...
  
  // Track conversion via Measurement Protocol (server-side, more reliable)
  // Or just track client-side in the form onSuccess callback
}

// Client component — track after confirmed server success
async function handleSubmit(data) {
  const result = await submitContactForm(data)
  if (result.success) {
    trackEvent('generate_lead', 'contact', 'contact-form')
    router.push('/contact/success')
  }
}
```

## Environment Guard

Never send analytics events in development:

```typescript
// lib/analytics.ts
export function trackEvent(action: string, category: string, label?: string) {
  if (process.env.NODE_ENV !== 'production') return
  if (!window.gtag) return
  window.gtag('event', action, { event_category: category, event_label: label })
}
```

## Privacy Considerations

For GDPR/CCPA compliance, only load GA after consent. For local businesses in the US (Idaho), the legal requirement is lower, but best practice:

```typescript
// Only load if consent given (store in localStorage or cookie)
const hasConsent = localStorage.getItem('analytics-consent') === 'true'
if (hasConsent) {
  // render the GA Script component
}
```

For JRS Auto Repair specifically — US-only, no EU visitors expected, consent banner is optional but good practice. Include it to future-proof.

## What to Track for Local Business

| Event | Why |
|---|---|
| Click "Call Now" | Highest intent signal |
| Submit contact form | Lead conversion |
| View service page | Interest signal |
| Blog post read time | Content quality indicator |
| Click directions | Near-purchase signal |

Avoid tracking every click — it creates noise. Focus on events that indicate intent or conversion.
