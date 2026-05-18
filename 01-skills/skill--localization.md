# Skill: Localization (i18n)

## Overview

Localization (l10n) serves translated content and locale-specific formatting (dates, numbers, currencies) to users based on their language. Internationalization (i18n) is the code architecture that enables localization. Use `next-intl` for Next.js App Router — it handles routing, SSR, and client components correctly.

## Setup (next-intl)

```bash
npm install next-intl
```

```
src/
  messages/
    en.json
    es.json
    pt.json
  i18n.ts
  middleware.ts
```

```ts
// i18n.ts
import { getRequestConfig } from 'next-intl/server'

export default getRequestConfig(async ({ locale }) => ({
  messages: (await import(`./messages/${locale}.json`)).default,
}))
```

```ts
// middleware.ts
import createMiddleware from 'next-intl/middleware'

export default createMiddleware({
  locales: ['en', 'es', 'pt'],
  defaultLocale: 'en',
  localePrefix: 'as-needed',  // /en/... for non-default, /... for default
})

export const config = { matcher: ['/((?!api|_next|_vercel|.*\\..*).*)'] }
```

## Message Files

```json
// messages/en.json
{
  "nav": {
    "home": "Home",
    "about": "About",
    "contact": "Contact"
  },
  "invoice": {
    "title": "Invoice #{number}",
    "total": "Total: {amount}",
    "dueDate": "Due {date}",
    "itemCount": "{count, plural, one {# item} other {# items}}"
  },
  "error": {
    "notFound": "Page not found",
    "serverError": "Something went wrong"
  }
}
```

```json
// messages/es.json
{
  "nav": {
    "home": "Inicio",
    "about": "Acerca de",
    "contact": "Contacto"
  },
  "invoice": {
    "title": "Factura #{number}",
    "total": "Total: {amount}",
    "dueDate": "Vence el {date}",
    "itemCount": "{count, plural, one {# artículo} other {# artículos}}"
  }
}
```

## Using Translations

```tsx
// Server Component
import { getTranslations } from 'next-intl/server'

export default async function InvoicePage({ params }: { params: { id: string } }) {
  const t = await getTranslations('invoice')
  const invoice = await getInvoice(params.id)

  return (
    <div>
      <h1>{t('title', { number: invoice.number })}</h1>
      <p>{t('total', { amount: formatCurrency(invoice.total) })}</p>
    </div>
  )
}
```

```tsx
// Client Component
'use client'
import { useTranslations } from 'next-intl'

export function NavMenu() {
  const t = useTranslations('nav')
  return (
    <nav>
      <a href="/">{t('home')}</a>
      <a href="/about">{t('about')}</a>
    </nav>
  )
}
```

## Number and Currency Formatting

Use `Intl.NumberFormat` — never hard-code currency symbols:

```ts
function formatCurrency(amountCents: number, locale: string, currency: string): string {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
  }).format(amountCents / 100)
}

formatCurrency(150000, 'en-US', 'USD')  // '$1,500.00'
formatCurrency(150000, 'es-ES', 'EUR')  // '1.500,00 €'
formatCurrency(150000, 'pt-BR', 'BRL')  // 'R$ 1.500,00'
```

## Date Formatting

```ts
function formatDate(date: Date, locale: string): string {
  return new Intl.DateTimeFormat(locale, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  }).format(date)
}

formatDate(new Date('2026-05-18'), 'en-US')  // 'May 18, 2026'
formatDate(new Date('2026-05-18'), 'es-ES')  // '18 de mayo de 2026'
formatDate(new Date('2026-05-18'), 'ja-JP')  // '2026年5月18日'
```

## Locale Detection

```ts
// Detect from Accept-Language header (server-side)
function detectLocale(acceptLanguage: string | null, supported: string[]): string {
  if (!acceptLanguage) return 'en'
  
  const preferred = acceptLanguage
    .split(',')
    .map(s => s.split(';')[0].trim().split('-')[0])
  
  return preferred.find(lang => supported.includes(lang)) ?? 'en'
}
```

`next-intl` middleware handles this automatically — only implement manually for edge cases.

## Pluralization

ICU message format handles pluralization correctly per locale:

```json
{
  "results": "{count, plural, =0 {No results} one {# result} other {# results}}"
}
```

```tsx
t('results', { count: 0 })   // 'No results'
t('results', { count: 1 })   // '1 result'
t('results', { count: 42 })  // '42 results'
```

Some languages (Russian, Arabic) have more plural forms than English. ICU handles these automatically when you add the correct messages.

## RTL Support (Arabic, Hebrew)

```tsx
// Root layout
const dir = locale === 'ar' || locale === 'he' ? 'rtl' : 'ltr'
<html lang={locale} dir={dir}>
```

```css
/* Use logical properties instead of left/right */
.card {
  padding-inline-start: 1rem;  /* left in LTR, right in RTL */
  margin-inline-end: 0.5rem;   /* right in LTR, left in RTL */
}
```

Tailwind v3+ supports `rtl:` modifier: `rtl:text-right`. Tailwind v4 uses logical properties by default.
