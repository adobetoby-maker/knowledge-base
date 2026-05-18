# SEO: Canonical Tags

## Overview

Canonical tags tell Google which version of a page is the "real" one when multiple URLs serve the same or similar content. Without them, Google may split ranking signals across duplicates or choose the wrong version to index.

## When Canonical Tags Are Needed

### Duplicate Content Scenarios

```
URL with/without trailing slash:
  /blog/post-slug
  /blog/post-slug/

Query parameters (tracking, sorting):
  /products
  /products?sort=price
  /products?utm_source=email

HTTP vs HTTPS (shouldn't happen, but fix if it does):
  http://example.com/page
  https://example.com/page

www vs non-www:
  https://www.example.com/page
  https://example.com/page

Pagination:
  /blog (page 1)
  /blog?page=2
  /blog?page=3
```

### Syndicated Content

If your article is also published on Medium, LinkedIn, or another domain, add a canonical pointing back to your site on those copies.

## Implementation in Next.js

```tsx
// app/blog/[slug]/page.tsx
import type { Metadata } from 'next'

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const post = await getPost(params.slug)
  const canonical = `https://yoursite.com/blog/${post.slug}`

  return {
    alternates: {
      canonical,  // Next.js adds <link rel="canonical" href="..." />
    },
    // ... other metadata
  }
}
```

## Self-Referencing Canonicals

Every page should have a canonical that points to itself:

```tsx
// In your root layout or a metadata helper
export function generateMetadata({ pathname }: { pathname: string }): Metadata {
  return {
    alternates: {
      canonical: `https://yoursite.com${pathname}`,
    },
  }
}
```

Self-referencing canonicals prevent Google from choosing a different canonical for you (often with added query params).

## Pagination

For paginated content, canonicalize to the first page OR let each page be indexed independently:

```
Option A: All pagination pages canonical → page 1
  Page 1: canonical="https://site.com/blog"
  Page 2: canonical="https://site.com/blog"  ← same
  Page 3: canonical="https://site.com/blog"  ← same

  Use when: pagination is purely for browsing, all articles appear in full text
  Risk: pages 2-3 may be de-indexed, losing links to older posts

Option B: Each page has its own self-canonical
  Page 1: canonical="https://site.com/blog"
  Page 2: canonical="https://site.com/blog?page=2"  ← self
  Page 3: canonical="https://site.com/blog?page=3"  ← self

  Use when: older paginated content needs to rank on its own
```

## Canonical vs noindex

Don't combine canonical and noindex on the same page — they conflict:

```html
<!-- Confusing: "Index this page but it's also a copy of another?" -->
<link rel="canonical" href="https://site.com/other-page" />
<meta name="robots" content="noindex" />
```

If you don't want the page indexed, use `noindex`. Use canonical only when you want it indexed as the same as another URL.

## Cross-Domain Canonical

When content is syndicated to another domain:

```html
<!-- On the syndicated copy at partner-site.com -->
<link rel="canonical" href="https://your-original-site.com/article-slug" />
```

Google usually respects this. The original site gets the ranking credit.

## Checking Canonicals

```bash
# Check rendered canonical tag
curl -s https://yoursite.com/blog/post-slug | grep -i canonical

# Check in Google Search Console
# Coverage → Valid → Google-selected canonical column
# If Google chose a different canonical than yours, investigate why
```

## Common Mistakes

**Canonical points to redirect chain**: The canonical URL itself redirects. Point canonicals directly to the final URL.

**Inconsistent protocols**: `http://` canonical on `https://` page — always use `https://`.

**Trailing slash inconsistency**: Pick one (`/page` or `/page/`) and use it consistently in all canonicals. Configure your server to redirect to your canonical form.

**Multiple canonical tags**: Only one canonical per page. Multiple tags confuse crawlers, which may ignore all of them.

**Canonical to a 404**: The target of your canonical must return 200. Pointing to a 404 or redirect confuses Google.
