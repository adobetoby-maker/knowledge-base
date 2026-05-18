# Multi-Language (i18n)

## Library Choice

For Next.js App Router: use `next-intl`. It supports Server Components natively, handles routing, and has TypeScript support.

For TanStack Start: use `i18next` + `react-i18next`.

```bash
# Next.js:
npm install next-intl

# TanStack Start:
npm install i18next react-i18next i18next-browser-languagedetector
```

## next-intl Setup (Next.js)

**File structure:**
```
messages/
  en.json
  es.json
  pt.json
src/
  i18n.ts
  middleware.ts
  app/[locale]/
    layout.tsx
    page.tsx
```

```typescript
// messages/en.json
{
  "nav": { "home": "Home", "about": "About" },
  "hero": {
    "title": "Welcome to {siteName}",
    "cta": "Get started"
  },
  "invoice": {
    "status": {
      "paid": "Paid",
      "pending": "Pending",
      "overdue": "Overdue"
    }
  }
}

// src/i18n.ts
import { getRequestConfig } from 'next-intl/server'

export default getRequestConfig(async ({ locale }) => ({
  messages: (await import(`../messages/${locale}.json`)).default,
}))

// src/middleware.ts
import createMiddleware from 'next-intl/middleware'

export default createMiddleware({
  locales: ['en', 'es', 'pt'],
  defaultLocale: 'en',
  localePrefix: 'always',  // /en/about, /es/about
})

export const config = { matcher: ['/((?!api|_next|.*\\..*).*)'] }
```

## Using Translations

```typescript
// Server Component:
import { getTranslations } from 'next-intl/server'

export default async function HeroSection() {
  const t = await getTranslations('hero')
  
  return (
    <section>
      <h1>{t('title', { siteName: "Jr.'s Auto Repair" })}</h1>
      <a href="/contact">{t('cta')}</a>
    </section>
  )
}

// Client Component:
'use client'
import { useTranslations } from 'next-intl'

export function InvoiceStatus({ status }: { status: string }) {
  const t = useTranslations('invoice.status')
  return <span>{t(status)}</span>
}
```

## Locale Detection in Middleware

```typescript
// Redirect root to browser's preferred locale:
export default createMiddleware({
  locales: ['en', 'es', 'pt'],
  defaultLocale: 'en',
  localeDetection: true,  // reads Accept-Language header
})
```

## Language Switcher

```typescript
'use client'
import { useLocale } from 'next-intl'
import { useRouter, usePathname } from 'next/navigation'

const LANGUAGES = [
  { code: 'en', label: 'English' },
  { code: 'es', label: 'Español' },
  { code: 'pt', label: 'Português' },
]

export function LanguageSwitcher() {
  const locale = useLocale()
  const router = useRouter()
  const pathname = usePathname()
  
  function switchLocale(newLocale: string) {
    // Replace /en/... with /es/...
    const newPath = pathname.replace(`/${locale}`, `/${newLocale}`)
    router.push(newPath)
  }
  
  return (
    <div className="flex gap-2">
      {LANGUAGES.map(lang => (
        <button
          key={lang.code}
          onClick={() => switchLocale(lang.code)}
          className={cn('text-sm', locale === lang.code && 'font-semibold underline')}
        >
          {lang.label}
        </button>
      ))}
    </div>
  )
}
```

## Number and Date Formatting

```typescript
// Server Component:
import { getFormatter } from 'next-intl/server'

const format = await getFormatter()

format.number(1234567.89, { style: 'currency', currency: 'USD' })  // $1,234,567.89
format.dateTime(new Date(), { dateStyle: 'long' })                  // January 15, 2025
format.relativeTime(-3, 'day')                                      // 3 days ago
```

## Hreflang for SEO

Each page needs alternate links:

```typescript
// app/[locale]/layout.tsx
export async function generateMetadata({ params }: { params: { locale: string } }) {
  return {
    alternates: {
      languages: {
        'en': '/en',
        'es': '/es',
        'pt': '/pt',
        'x-default': '/en',
      },
    },
  }
}
```

## When NOT to Use i18n

Avoid adding i18n to admin dashboards — translation overhead rarely pays off for internal tools. Add i18n to:
- Public marketing pages
- Customer-facing portals
- Any page that will be indexed in multiple languages
