# SEO: International SEO / Hreflang

## Overview

International SEO tells Google which language/region each page targets. Without it, Google may show the wrong language version in search results. Implement `hreflang` tags on every page with a corresponding alternate language version. URL structure choice — subdirectory, subdomain, or ccTLD — has long-term implications; subdirectory is recommended for most sites.

## URL Structure Options

| Approach | Example | Pros | Cons |
|---|---|---|---|
| **Subdirectory** (recommended) | `example.com/es/` | Shares domain authority | Slightly complex routing |
| Subdomain | `es.example.com` | Easy to configure | Treated as separate domain |
| ccTLD | `example.es` | Strongest geo signal | Expensive, multiple domains |

Subdirectory is the pragmatic choice for most apps — shares domain authority, easier to manage in a monorepo.

## Locale Detection and Routing (Next.js)

```ts
// next.config.ts
const nextConfig = {
  i18n: {
    locales: ['en', 'es', 'pt-BR', 'de'],
    defaultLocale: 'en',
    localeDetection: true,
  },
}
```

With App Router (no built-in i18n routing), use middleware:

```ts
// middleware.ts
import { match } from '@formatjs/intl-localematcher'
import Negotiator from 'negotiator'

const SUPPORTED_LOCALES = ['en', 'es', 'pt-BR']
const DEFAULT_LOCALE = 'en'

function getLocale(req: NextRequest): string {
  const headers = { 'accept-language': req.headers.get('accept-language') ?? '' }
  const languages = new Negotiator({ headers }).languages()
  return match(languages, SUPPORTED_LOCALES, DEFAULT_LOCALE)
}

export function middleware(req: NextRequest) {
  const pathname = req.nextUrl.pathname
  const hasLocale = SUPPORTED_LOCALES.some(l => pathname.startsWith(`/${l}`))

  if (!hasLocale) {
    const locale = getLocale(req)
    return NextResponse.redirect(new URL(`/${locale}${pathname}`, req.url))
  }
}
```

## Hreflang Implementation

```ts
// In generateMetadata for each page
export async function generateMetadata({ params }: { params: { lang: string; slug: string } }): Promise<Metadata> {
  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL!

  return {
    alternates: {
      canonical: `${baseUrl}/${params.lang}/blog/${params.slug}`,
      languages: {
        'en': `${baseUrl}/en/blog/${params.slug}`,
        'es': `${baseUrl}/es/blog/${params.slug}`,
        'pt-BR': `${baseUrl}/pt-BR/blog/${params.slug}`,
        'x-default': `${baseUrl}/en/blog/${params.slug}`,  // Fallback for unmatched
      },
    },
  }
}
```

## hreflang in the Head

Next.js `alternates.languages` generates `<link rel="alternate" hreflang="...">` tags automatically. Verify the output:

```html
<link rel="canonical" href="https://example.com/en/blog/seo-tips" />
<link rel="alternate" hreflang="en" href="https://example.com/en/blog/seo-tips" />
<link rel="alternate" hreflang="es" href="https://example.com/es/blog/consejos-seo" />
<link rel="alternate" hreflang="pt-BR" href="https://example.com/pt-BR/blog/dicas-seo" />
<link rel="alternate" hreflang="x-default" href="https://example.com/en/blog/seo-tips" />
```

**Critical:** hreflang must be reciprocal — every version must link to all others, including itself.

## Content Translation vs. Localization

```
Translation = same content, different language
Localization = adapted for the market (currency, date format, examples, idioms)
```

For SEO, partial translation is better than none — but machine-translated content with no editing can trigger thin content penalties. Minimum viable: translate title, meta description, headings, and intro paragraph.

## Language Middleware (Detection + Redirect)

```ts
// lib/locale.ts
export const LOCALE_COUNTRY_MAP: Record<string, string> = {
  'pt-BR': 'Brazil',
  'pt':    'Portugal',
  'es-MX': 'Mexico',
  'es':    'Spain/Latin America',
  'de':    'Germany/Austria/Switzerland',
  'en':    'English-speaking',
}

// Use Cloudflare's cf-ipcountry header for geo-based default
export function getLocaleFromCountry(countryCode: string): string {
  const map: Record<string, string> = {
    BR: 'pt-BR',
    MX: 'es-MX',
    ES: 'es',
    DE: 'de',
    AT: 'de',
  }
  return map[countryCode] ?? 'en'
}
```

## Key Rules

- `x-default` hreflang is required — it tells Google which page to show when no locale matches.
- Hreflang is reciprocal — if `/en/` links to `/es/`, then `/es/` must link back to `/en/`. Broken reciprocal links nullify both.
- Don't use `hreflang` for content that only exists in one language — it creates confusion without benefit.
- Locale in URL path (`/es/`) is preferred over cookie/session-based locale for bot crawlability.
- Separate sitemaps per locale (or a sitemap index) make it easier for Google to discover all locale variants.
