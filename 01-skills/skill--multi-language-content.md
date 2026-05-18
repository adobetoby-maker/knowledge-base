# Skill: Multi-Language Content Management

## Overview
Storing translated content with locale keys lets a single data model serve multiple languages without duplicating schema. A fallback strategy to the default locale prevents broken pages when translations lag behind new content. CI-gated translation completeness (≥ 95%) catches gaps before they reach production.

## Implementation / Key Points

### Content Storage Schema
```ts
// Every content record carries a locale map
interface ContentRecord {
  slug: string;
  publishedAt: string;
  translations: Record<string, ContentTranslation>; // key = BCP-47 locale
}

interface ContentTranslation {
  title: string;
  excerpt: string;
  body: string;
  translatedAt: string;
  reviewedAt?: string;        // null = machine draft, set = human-approved
  machineTranslated: boolean;
}
```

### Retrieval with Fallback
```ts
function getLocalizedContent(
  slug: string,
  locale: string,
  fallback = 'en'
): ContentTranslation {
  const record = db.content.findBySlug(slug);
  return record.translations[locale]
    ?? record.translations[fallback]
    ?? throwNotFound(slug);
}
```
Always return the fallback locale object, not a partial merge — partial merges produce mixed-language pages that confuse readers and translators alike.

### Translation Completeness Check (CI)
```ts
// scripts/check-translations.ts
const THRESHOLD = 0.95;
const baseKeys = Object.keys(en);       // default locale is the source of truth

for (const locale of supportedLocales) {
  const keys = Object.keys(translations[locale] ?? {});
  const coverage = keys.filter(k => baseKeys.includes(k)).length / baseKeys.length;
  if (coverage < THRESHOLD) {
    console.error(`${locale}: ${(coverage * 100).toFixed(1)}% — below ${THRESHOLD * 100}%`);
    process.exit(1);
  }
}
```

### Machine Translation → Human Review Pipeline
1. New content published in default locale.
2. CI/webhook triggers machine translation job (DeepL / Google Translate API).
3. Translated record saved with `machineTranslated: true`, `reviewedAt: null`.
4. CMS marks untranslated content visually (e.g. yellow badge).
5. Human translator reviews, edits, sets `reviewedAt`.
6. Only reviewed translations appear in production; machine drafts show fallback.

### URL Structure
```
/en/blog/slug       ← canonical
/ja/blog/slug       ← locale prefix in path (preferred over query param)
/                   ← redirect to detected locale based on Accept-Language header
```
Always include `hreflang` alternate links in `<head>` for SEO.

## Key Rules
- Store locale as BCP-47 tag (`en-US`, `ja`, `pt-BR`) — never a custom string.
- Never mix translations in a single string field; always separate columns or a translations map.
- Default locale content is authoritative; translations must never block a publish.
- Machine translations must be flagged; show fallback until human-reviewed.
- CI fails if any supported locale drops below 95% translation coverage.
- Slug is locale-independent; only the translation changes — never duplicate slugs per locale.
- `reviewedAt` timestamp also serves as an audit trail for translator accountability.
