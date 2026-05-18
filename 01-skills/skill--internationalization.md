# Internationalization (i18n)

## Scope in This Workspace

- `language-lens-elite` — multilingual UI (English, Japanese, Spanish, Korean)
- `climb-brasil` — EN/PT/ES target markets
- `jrs-auto-repair` — English only (no i18n needed)
- `manage-worker-bee` — English only (internal tool)

## next-intl (Recommended for Next.js)

```bash
npm install next-intl
```

### Project Structure

```
app/
  [locale]/
    layout.tsx
    page.tsx
    blog/
      page.tsx
messages/
  en.json
  pt.json
  es.json
```

### Message Files

```json
// messages/en.json
{
  "HomePage": {
    "title": "Learn Portuguese in Brazil",
    "cta": "Start Learning",
    "hero": {
      "tagline": "Speak Portuguese like a local"
    }
  },
  "Navigation": {
    "home": "Home",
    "destinations": "Destinations",
    "blog": "Blog"
  }
}
```

### Configuration

```typescript
// i18n/request.ts
import { getRequestConfig } from 'next-intl/server'
import { routing } from './routing'

export default getRequestConfig(async ({ requestLocale }) => {
  let locale = await requestLocale
  if (!routing.locales.includes(locale as 'en' | 'pt' | 'es')) {
    locale = routing.defaultLocale
  }

  return {
    locale,
    messages: (await import(`../messages/${locale}.json`)).default,
  }
})

// i18n/routing.ts
import { defineRouting } from 'next-intl/routing'

export const routing = defineRouting({
  locales: ['en', 'pt', 'es'],
  defaultLocale: 'en',
})
```

### Middleware for Locale Detection

```typescript
// middleware.ts
import createMiddleware from 'next-intl/middleware'
import { routing } from './i18n/routing'

export default createMiddleware(routing)

export const config = {
  matcher: ['/((?!api|_next|_vercel|.*\\..*).*)'],
}
```

### Using Translations

```typescript
// app/[locale]/page.tsx
import { useTranslations } from 'next-intl'

export default function HomePage() {
  const t = useTranslations('HomePage')
  
  return (
    <main>
      <h1>{t('title')}</h1>
      <p>{t('hero.tagline')}</p>
      <button>{t('cta')}</button>
    </main>
  )
}
```

### Server Component Translations

```typescript
// For Server Components, use getTranslations
import { getTranslations } from 'next-intl/server'

export default async function ServerPage() {
  const t = await getTranslations('HomePage')
  return <h1>{t('title')}</h1>
}
```

## TanStack Start i18n (language-lens-elite)

language-lens-elite uses TanStack Start with its own i18n approach:

```typescript
// src/state/app-state.tsx — language stored in app state
interface AppState {
  selectedLanguage: 'japanese' | 'spanish' | 'korean' | 'portuguese'
  // ...
}

// UI strings kept in English (the interface is English, the learning content is multilingual)
// Translated content is in the articles/exercises data, not in UI strings
```

## Language-Specific Patterns

### Number and Date Formatting

```typescript
// Use Intl API — no library needed
const price = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
}).format(150.99)  // "R$\xa0150,99"

const date = new Intl.DateTimeFormat('pt-BR', {
  dateStyle: 'long',
}).format(new Date())  // "18 de maio de 2026"
```

### Pluralization with next-intl

```json
// messages/en.json
{
  "Reviews": {
    "count": "{count, plural, =0 {No reviews} =1 {1 review} other {# reviews}}"
  }
}
```

```typescript
t('Reviews.count', { count: reviewCount })
```

## URL Structure

Two approaches:
1. **Path-based** — `/en/about`, `/pt/about` (recommended, SEO-friendly)
2. **Subdomain** — `en.site.com`, `pt.site.com` (complex to set up)

For climb-brasil: `/` is English default, `/pt/`, `/es/` for other locales.

## hreflang Tags for SEO

For pages available in multiple languages, add hreflang:

```typescript
// app/[locale]/layout.tsx
export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params
  return {
    alternates: {
      canonical: `https://climbbrasil.com/${locale}`,
      languages: {
        'en': 'https://climbbrasil.com/en',
        'pt': 'https://climbbrasil.com/pt',
        'es': 'https://climbbrasil.com/es',
        'x-default': 'https://climbbrasil.com',
      },
    },
  }
}
```
