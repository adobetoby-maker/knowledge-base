# Skill: Self-Hosted Analytics with Plausible

## Overview
Third-party analytics like Google Analytics collect user data on behalf of the analytics company, require cookie consent banners in GDPR/CCPA jurisdictions, and are blocked by ~40% of users via ad blockers. Plausible is privacy-first: no cookies, no cross-site tracking, GDPR compliant out of the box, and can be self-hosted in EU for full data residency. The tradeoff is no user-level tracking — you get aggregate stats, not user journeys.

## Docker Compose Setup

```yaml
# docker-compose.yml
version: "3.8"
services:
  plausible_db:
    image: postgres:16-alpine
    volumes:
      - plausible-db:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}

  plausible_events_db:
    image: clickhouse/clickhouse-server:24-alpine
    volumes:
      - event-data:/var/lib/clickhouse
      - ./clickhouse/clickhouse-config.xml:/etc/clickhouse-server/config.d/logging.xml
    ulimits:
      nofile:
        soft: 262144
        hard: 262144

  plausible:
    image: ghcr.io/plausible/community-edition:v2
    command: sh -c "sleep 10 && /entrypoint.sh db createdb && /entrypoint.sh db migrate && /entrypoint.sh run"
    depends_on:
      - plausible_db
      - plausible_events_db
    ports:
      - "8000:8000"
    environment:
      BASE_URL: https://analytics.yourdomain.com
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}  # 64+ char random string
      DATABASE_URL: postgres://postgres:${POSTGRES_PASSWORD}@plausible_db:5432/plausible
      CLICKHOUSE_DATABASE_URL: http://plausible_events_db:8123/plausible_events
      DISABLE_REGISTRATION: true  # after first admin setup

volumes:
  plausible-db:
  event-data:
```

```bash
# Generate SECRET_KEY_BASE
openssl rand -base64 64
```

## Script Tag Integration

```html
<!-- In <head> — no cookie consent required -->
<script
  defer
  data-domain="yourdomain.com"
  src="https://analytics.yourdomain.com/js/script.js"
></script>
```

Self-hosted script URL uses your own domain — bypasses ad blockers that block `plausible.io`.

For Next.js:

```tsx
// app/layout.tsx
import Script from 'next/script'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <head>
        <Script
          defer
          data-domain={process.env.NEXT_PUBLIC_SITE_DOMAIN}
          src={`${process.env.NEXT_PUBLIC_PLAUSIBLE_URL}/js/script.js`}
          strategy="afterInteractive"
        />
      </head>
      <body>{children}</body>
    </html>
  )
}
```

## Custom Goal Events

```ts
// lib/analytics.ts
declare global {
  interface Window {
    plausible?: (event: string, options?: { props?: Record<string, string | number> }) => void
  }
}

export function trackEvent(name: string, props?: Record<string, string | number>) {
  if (typeof window === 'undefined') return
  window.plausible?.(name, props ? { props } : undefined)
}
```

```tsx
// Usage in component
import { trackEvent } from '@/lib/analytics'

function PricingCard({ plan }: { plan: string }) {
  return (
    <button
      onClick={() => {
        trackEvent('Upgrade Click', { plan })
        router.push('/checkout')
      }}
    >
      Upgrade to {plan}
    </button>
  )
}
```

Register goal events in Plausible dashboard under Goals before sending — otherwise they don't appear in reports.

## Custom Properties (Dimensions)

Track additional context on pageviews:

```html
<!-- Static meta tag approach -->
<meta name="plausible-event-user_type" content="admin" />
```

Or dynamically:

```ts
// Override the default pageview with custom properties
window.plausible?.('pageview', { props: { user_type: 'admin', plan: 'pro' } })
```

## Outbound Link Tracking

```html
<!-- Enable with script extension -->
<script
  defer
  data-domain="yourdomain.com"
  src="https://analytics.yourdomain.com/js/script.outbound-links.js"
></script>
```

Outbound link clicks tracked automatically as `Outbound Link: Click` events.

## Key Rules
- No cookie consent banner needed — Plausible uses no cookies and no cross-site tracking
- Data-domain must match the domain exactly (no `www` mismatch)
- Use your own domain for the script src — reduces ad blocker blocking rate
- Custom events must be registered in the dashboard before they show up in reports
- `DISABLE_REGISTRATION: true` after setting up first admin account
- Plausible aggregates, not user-level data — you cannot identify individual users (that's the point)
- EU data residency: self-host in an EU region if you need GDPR compliance without consent
- Reverse proxy the script through your own server for maximum ad blocker bypass
