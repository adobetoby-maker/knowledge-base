# hreflang Implementation for Multilingual SEO

## Purpose and Why It's Easy to Get Wrong

`hreflang` tells Google which language/region version of a page to serve to which user. Without it, Google guesses — and may serve Spanish content to English users or index only one language variant while suppressing others. The tag is bilateral: *every* alternate URL must reference *every other* alternate URL, including itself. A broken hreflang set (where page A references B but B doesn't reference A) causes Google to ignore the entire set.

## The Self-Referential Requirement

Every page in an hreflang set must include a `<link rel="alternate" hreflang>` tag pointing to *itself*, in addition to all other variants. This is the most commonly missed part.

```html
<!-- On /en/about -->
<link rel="alternate" hreflang="en" href="https://example.com/en/about" />
<link rel="alternate" hreflang="fr" href="https://example.com/fr/about" />
<link rel="alternate" hreflang="de" href="https://example.com/de/about" />
<link rel="alternate" hreflang="x-default" href="https://example.com/about" />

<!-- On /fr/about — same set, every page has all variants -->
<link rel="alternate" hreflang="en" href="https://example.com/en/about" />
<link rel="alternate" hreflang="fr" href="https://example.com/fr/about" />
<link rel="alternate" hreflang="de" href="https://example.com/de/about" />
<link rel="alternate" hreflang="x-default" href="https://example.com/about" />
```

## x-default: The Fallback

`hreflang="x-default"` specifies which URL Google should serve when no language-specific variant matches the user's locale. Point it to:
- Your language selector page (e.g., `/select-language`) if you have one
- Your default-language homepage if you don't have a selector

The `x-default` page does not need to appear in the set as a language-specific variant. It is purely the fallback destination.

```html
<!-- x-default pointing to a language selector -->
<link rel="alternate" hreflang="x-default" href="https://example.com/choose-language" />

<!-- x-default pointing to English as the default -->
<link rel="alternate" hreflang="x-default" href="https://example.com/en/" />
```

Do not point `x-default` to a URL that already appears as a language variant (e.g., setting `x-default` to the same href as `hreflang="en"` is technically allowed but signals to Google that English is the universal default — fine if that's intentional).

## Language-Only vs Language+Region Codes

Use language-only codes unless you have genuinely different content for different regions of the same language:

```
hreflang="es"         # all Spanish-speaking users
hreflang="es-MX"      # Mexican Spanish specifically
hreflang="es-ES"      # Castilian Spanish specifically
```

If you use `es-MX` and `es-ES` but not `es`, users in Argentina, Colombia, etc. get no match and fall to `x-default`. For most sites, language-only codes (`en`, `fr`, `de`, `es`) are correct. Add region codes only when the content is genuinely region-specific (pricing, legal, cultural references).

Language codes are ISO 639-1 (two-letter, lowercase: `en`, `fr`, `de`). Country codes are ISO 3166-1 alpha-2 (two-letter, UPPERCASE: `US`, `GB`, `DE`). Combined: `en-GB`, `zh-TW`.

## Sitemap as Alternative to Head Tags

For large sites (1000+ pages), maintaining hreflang in every page's `<head>` is operationally complex. Use the sitemap method instead:

```xml
<url>
  <loc>https://example.com/en/about</loc>
  <xhtml:link rel="alternate" hreflang="en" href="https://example.com/en/about"/>
  <xhtml:link rel="alternate" hreflang="fr" href="https://example.com/fr/about"/>
  <xhtml:link rel="alternate" hreflang="x-default" href="https://example.com/about"/>
</url>
```

Add the xmlns declaration: `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">`.

The sitemap method is mutually exclusive per page — don't implement both head tags and sitemap entries for the same page, or conflicting signals result.

## Next.js Implementation

In App Router, generate hreflang via `generateMetadata`:

```typescript
export async function generateMetadata({ params }: { params: { lang: string } }) {
  const { lang } = params
  const languages = {
    en: '/en/about',
    fr: '/fr/about',
    'x-default': '/about',
  }
  return {
    alternates: {
      canonical: `https://example.com/${lang}/about`,
      languages,
    },
  }
}
```

Next.js renders this as `<link rel="alternate" hreflang>` tags in the `<head>` automatically.

## Key Rules

- Every page in an hreflang set must reference all other pages *and* itself — missing self-reference causes Google to ignore the entire set
- `x-default` must be present on every page in the set; point it to a language selector or your default-language URL
- Use language-only codes (`en`, `fr`, `es`) unless you have content that genuinely differs by region, not just by dialect
- Don't mix head-tag hreflang and sitemap hreflang for the same pages — use one method sitewide
- Validate with Google Search Console's International Targeting report and Screaming Frog's hreflang export — manual validation of bilateral links is error-prone
