# SEO Meta Tags Advanced

## Next.js Metadata API

Use the `metadata` export — never add `<meta>` tags directly in `<head>`:

```typescript
// app/page.tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Auto Repair in Twin Falls, ID | Jr.'s Auto Repair',
  description: 'Honest auto repair in Twin Falls, Idaho. Oil changes, brakes, diagnostics. 4.8★ rating. Call (208) 595-2101 or book online.',
  openGraph: {
    title: 'Jr.'s Auto Repair — Twin Falls, Idaho',
    description: 'Honest work, fair prices, done right the first time.',
    url: 'https://jrsautorepair.com',
    siteName: 'Jr.'s Auto Repair',
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
  },
  alternates: {
    canonical: 'https://jrsautorepair.com',
  },
}
```

## Title Template (Root Layout)

Set a template so child pages don't repeat the site name:

```typescript
// app/layout.tsx
export const metadata: Metadata = {
  title: {
    template: '%s | Jr.'s Auto Repair',
    default: 'Jr.'s Auto Repair — Twin Falls, Idaho',
  },
  description: 'Trusted auto repair in Twin Falls, ID since 2010.',
}

// Child page:
export const metadata: Metadata = {
  title: 'Oil Change Service',
  // Renders: "Oil Change Service | Jr.'s Auto Repair"
}
```

## Dynamic Metadata Per Page

```typescript
// app/blog/[slug]/page.tsx
export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>
}): Promise<Metadata> {
  const { slug } = await params
  const article = getArticleBySlug(slug)
  
  if (!article) return { title: 'Article Not Found' }
  
  return {
    title: article.title,
    description: article.excerpt,
    openGraph: {
      title: article.title,
      description: article.excerpt,
      type: 'article',
      publishedTime: article.date,
      url: `https://jrsautorepair.com/blog/${slug}`,
    },
    alternates: {
      canonical: `https://jrsautorepair.com/blog/${slug}`,
    },
  }
}
```

## Title Formula for Local Business

```
[Service/Page Keyword] in [City, State] | [Business Name]
```

Examples:
- `Oil Change in Twin Falls, ID | Jr.'s Auto Repair`
- `Brake Repair Magic Valley Idaho | Jr.'s Auto Repair`

Title length: 50-60 characters. Google truncates beyond ~60.

## Description Formula

```
[What you do] in [location]. [Unique value]. [Call to action + trust signal].
```

Example:
```
Honest auto repair in Twin Falls, Idaho. Oil changes, brakes, diagnostics.
Call (208) 595-2101. 4.8★ · 146 reviews.
```

Length: 140-160 characters. Write for the human reader, not for keyword density.

## Canonical URLs

Prevent duplicate content penalties by always setting canonical:

```typescript
alternates: {
  canonical: `https://jrsautorepair.com/blog/${slug}`,
}
```

Set canonical to the clean URL — NOT to the URL with `?source=homepage` or other query params.

## Robots Directives Per Route

```typescript
// Public pages — index and follow (default):
robots: { index: true, follow: true }

// Admin/portal — exclude from indexing:
robots: { index: false, follow: false }
```

Global exclusions belong in `app/robots.ts`:
```typescript
disallow: ['/admin/', '/portal/', '/api/']
```

## Common Mistakes

- Same description on every page — each page needs its own unique, accurate description
- Business name first in title — lead with the keyword, e.g., "Oil Change" not "Jr.'s Auto Repair Oil Change"
- Keyword stuffed description — Google ignores stuffed descriptions and shows its own snippet instead
- Missing OG tags — social shares look bad without them, fewer clicks
- `noindex` accidentally set on public pages via copy-paste from admin route metadata
