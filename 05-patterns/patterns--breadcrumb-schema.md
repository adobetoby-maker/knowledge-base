# Pattern: BreadcrumbList JSON-LD Schema in Next.js

## Overview

Structured data for breadcrumbs (`BreadcrumbList`) tells search engines the hierarchical position of a page. Google uses it to display breadcrumb trails in search results instead of the raw URL. The implementation is straightforward, but common errors include: hardcoding the domain, generating schema in a client component (making it unavailable to crawlers), and forgetting the trailing home item.

## Why JSON-LD Over Microdata

JSON-LD is Google's preferred format and the most maintainable: it lives in a `<script>` tag, separate from your HTML structure. Microdata requires adding `itemscope`/`itemprop` attributes throughout your markup, coupling semantic markup to structured data. JSON-LD has no such coupling.

## Utility Function

```ts
// lib/schema/breadcrumbs.ts
type BreadcrumbItem = {
  name: string
  url: string
}

export function buildBreadcrumbSchema(
  items: BreadcrumbItem[],
  baseUrl: string = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://example.com'
): object {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, index) => ({
      '@type': 'ListItem',
      position: index + 1,  // 1-indexed per schema.org spec
      name: item.name,
      item: item.url.startsWith('http') ? item.url : `${baseUrl}${item.url}`,
    })),
  }
}
```

**Why full absolute URLs:** Schema.org requires `item` to be a fully qualified URL. Relative paths like `/blog/post` are invalid. Always prefix with the base URL if the path is relative.

**Why `NEXT_PUBLIC_SITE_URL`:** Hardcoding the domain makes the site break if the domain changes or the code is reused across environments. Pull from env vars and set a safe fallback.

## Page-Level Usage (Next.js App Router)

Schema must be rendered server-side so Googlebot sees it. In the App Router, do this in a Server Component:

```tsx
// app/blog/[slug]/page.tsx
import { buildBreadcrumbSchema } from '@/lib/schema/breadcrumbs'

export default async function BlogPostPage({ params }: { params: { slug: string } }) {
  const post = await getPost(params.slug)

  const breadcrumbs = [
    { name: 'Home', url: '/' },
    { name: 'Blog', url: '/blog' },
    { name: post.title, url: `/blog/${params.slug}` },
  ]

  const schema = buildBreadcrumbSchema(breadcrumbs)

  // JSON.stringify of a server-constructed object — not user input, safe for inline script
  return (
    <>
      <script
        type="application/ld+json"
        // NOTE: content is server-constructed from trusted data only, never from user input
        dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
      />
      <article>
        {/* page content */}
      </article>
    </>
  )
}
```

**Why `dangerouslySetInnerHTML` is safe here:** React's JSX normally HTML-escapes output to prevent XSS, which would corrupt raw `<script>` tag content. The `dangerouslySetInnerHTML` prop bypasses escaping. This is safe only because the data is fully server-controlled (not user input). Never pass user-supplied strings into the schema object without sanitizing.

## Reusable Schema Component

```tsx
// components/schema/BreadcrumbSchema.tsx
import { buildBreadcrumbSchema } from '@/lib/schema/breadcrumbs'

type Props = {
  items: { name: string; url: string }[]
}

export function BreadcrumbSchema({ items }: Props) {
  const schema = buildBreadcrumbSchema(items)
  const json = JSON.stringify(schema)

  return (
    <script
      type="application/ld+json"
      // Server-constructed from trusted sources only — not user input
      dangerouslySetInnerHTML={{ __html: json }}
    />
  )
}
```

## Dynamic Breadcrumbs from Route Segments

In the App Router, derive breadcrumbs from the URL automatically:

```ts
// lib/schema/buildBreadcrumbsFromPath.ts
export function buildBreadcrumbsFromPath(
  pathname: string,
  labels: Record<string, string> = {}
): { name: string; url: string }[] {
  const segments = pathname.split('/').filter(Boolean)
  let path = ''

  const items = [{ name: 'Home', url: '/' }]

  for (const segment of segments) {
    path += `/${segment}`
    const label = labels[segment]
      ?? labels[path]
      ?? segment.replace(/-/g, ' ').replace(/\b\w/g, c => c.toUpperCase())

    items.push({ name: label, url: path })
  }

  return items
}
```

Pass a `labels` map for segments with dynamic IDs:

```ts
buildBreadcrumbsFromPath('/blog/my-article-slug', {
  '/blog/my-article-slug': 'Why Rust is Fast',
})
```

## Pairing with Visual Breadcrumbs

The visual `<nav aria-label="Breadcrumb">` and JSON-LD schema should show the same items. Generate the array once, pass to both:

```tsx
// Single source of truth for both UI and schema
const breadcrumbs = [
  { name: 'Home', url: '/' },
  { name: 'Blog', url: '/blog' },
  { name: post.title, url: `/blog/${slug}` },
]

return (
  <>
    <BreadcrumbSchema items={breadcrumbs} />
    <BreadcrumbNav items={breadcrumbs} />
  </>
)
```

## Validation

Test with Google's Rich Results Test or Schema.org's validator. Common errors: missing `@context`, `position` starting at 0, relative URLs in `item`.

## Key Rules

- Render schema in a Server Component — Googlebot may not execute JavaScript; server-side rendering guarantees visibility
- Always use fully qualified URLs — relative paths are invalid in `item` fields per schema.org spec
- Pull base URL from env vars — hardcoding the domain breaks multi-environment setups
- Never pass user input directly into the schema object — inline scripts bypass React's HTML escaping
- Keep JSON-LD and visual breadcrumbs in sync — derive both from the same array to prevent drift
- Positions are 1-indexed — schema.org `ListItem.position` starts at 1, not 0
- Validate with Google's Rich Results Test before shipping — catches common structural errors
