# SEO: URL Structure

## Overview

URL structure affects indexability, crawl depth, and user trust. Short, descriptive, keyword-rich URLs outperform long parameter-heavy ones. Consistency matters more than perfection — pick a pattern and stick to it; changing URLs requires 301 redirects which lose some PageRank.

## URL Best Practices

```
Good:  /blog/auto-repair-tips
Bad:   /blog/post?id=1234&category=tips&source=email

Good:  /products/blue-denim-jacket
Bad:   /products/category.php?cat=3&sub=12&pid=489

Good:  /services/oil-change
Bad:   /pages/services/automotive/maintenance/oil-change-service
```

## Pattern Guidelines

| Rule | Example |
|---|---|
| Use hyphens, not underscores | `/car-repair` not `/car_repair` |
| Lowercase only | `/blog/seo-tips` not `/Blog/SEO-Tips` |
| No trailing slashes (or always trailing — be consistent) | `/about` consistently |
| Max 3-5 path segments | `/blog/topic/post-slug` |
| Keywords in slug, not stop words | `/seo-tools` not `/the-best-tools-for-seo` |
| Static slug for content pages | `/about` not `/page?name=about` |

## Slug Generation

```ts
function generateSlug(title: string): string {
  return title
    .toLowerCase()
    .normalize('NFD')                      // Decompose accented chars
    .replace(/[̀-ͯ]/g, '')       // Remove accent marks: café → cafe
    .replace(/[^a-z0-9\s-]/g, '')          // Remove special chars
    .replace(/\s+/g, '-')                  // Spaces to hyphens
    .replace(/-+/g, '-')                   // Deduplicate hyphens
    .replace(/^-|-$/g, '')                 // Trim leading/trailing hyphens
    .slice(0, 80)                          // Max length
}

// Examples:
generateSlug('Top 10 Tips: Auto Repair in Twin Falls!')
// → 'top-10-tips-auto-repair-in-twin-falls'

generateSlug("What's the Best Oil for Your Car?")
// → 'whats-the-best-oil-for-your-car'
```

## Unique Slug Enforcement

```ts
async function createUniqueSlug(baseSlug: string, table: string): Promise<string> {
  let slug = baseSlug
  let attempt = 0

  while (true) {
    const existing = await db.execute(
      sql`SELECT id FROM ${sql.identifier(table)} WHERE slug = ${slug} LIMIT 1`
    )
    if (!existing.length) return slug
    attempt++
    slug = `${baseSlug}-${attempt}`
  }
}

// Or add randomness for less collision-prone slugs
function generateSlugWithId(title: string, id: string): string {
  const base = generateSlug(title).slice(0, 60)
  return `${base}-${id.slice(0, 8)}`
}
```

## URL Hierarchy Strategy

```
/                               → Homepage
/blog                           → Blog index
/blog/[topic]                   → Topic index (optional)
/blog/[slug]                    → Blog post
/products                       → Product listing
/products/[category]            → Category page
/products/[category]/[slug]     → Product detail
/[city]                         → Local SEO city page (flat, not nested)
/services/[service]             → Service pages
/about                          → Static page
```

**Avoid deep nesting** — beyond 3 levels, Google deprioritizes crawling. Flat > deep.

## Category vs. Flat Blog Structure

Debate: `/blog/seo/keyword-research` vs `/blog/keyword-research`

- Flat (`/blog/keyword-research`) is better for SEO — shorter URL, less crawl depth.
- Category in URL helps humans understand context but doesn't add ranking value.
- If you use category prefix, it becomes part of the canonical URL and can't easily be changed.

## Canonical for URL Variants

Prevent duplicate content from tracking params and sorting:

```ts
// In Next.js metadata
alternates: {
  canonical: `${baseUrl}/products/blue-jacket`,  // Not /products/blue-jacket?color=blue&ref=email
}
```

## Enforce Trailing Slash Consistency

```ts
// next.config.ts
const nextConfig = {
  trailingSlash: false,  // /about not /about/
}
```

Or via middleware 301 redirect:

```ts
// middleware.ts
export function middleware(req: NextRequest) {
  const path = req.nextUrl.pathname
  if (path !== '/' && path.endsWith('/')) {
    return NextResponse.redirect(new URL(path.slice(0, -1), req.url), 301)
  }
}
```

## Key Rules

- Slugs are permanent — URL changes require 301 redirects; plan the structure before launch.
- Never put dates in URLs for evergreen content (`/blog/2021/01/seo-tips`) — the content ages even when the information doesn't.
- Product IDs in URLs (`/products/jacket-12345`) reduce slug collision but look less clean — weigh readability vs. simplicity.
- URL structure affects anchor text context — `/services/oil-change` signals "oil change service" to Google.
- Enforce lowercase redirect in middleware — `/Blog/Post-Name` and `/blog/post-name` are two different URLs to Google.
