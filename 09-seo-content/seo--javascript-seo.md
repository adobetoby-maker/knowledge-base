# SEO: JavaScript and Crawling

## Overview

Google crawls JavaScript but processes it in two waves: HTML is indexed immediately, JS is rendered later (hours to days). Bing and other crawlers render JS poorly or not at all. For SEO-critical content, serve it in the initial HTML response — don't rely on client-side rendering.

## Rendering Impact

| Rendering | Googlebot | Other bots | Time to index |
|---|---|---|---|
| Server-Side Rendering (SSR) | ✓ Full | ✓ Full | Hours |
| Static HTML (SSG) | ✓ Full | ✓ Full | Hours |
| Client-Side Only (CSR) | Partial | ✗ None | Days |
| Hybrid (Next.js App Router) | ✓ Full | ✓ Full | Hours |

## What Googlebot Sees

To test what Googlebot renders, use Google Search Console → URL Inspection → Test Live URL → View Rendered HTML. This shows the DOM after JavaScript execution.

Alternatively, use curl (no JS):
```bash
curl -A "Googlebot/2.1" https://example.com/page
```

The curl output should contain all critical text, headings, and metadata.

## Common JS SEO Problems

### Problem: Content loaded via useEffect

```tsx
// BAD: Heading only appears after JS runs
function BlogPost({ slug }: { slug: string }) {
  const [post, setPost] = useState<Post | null>(null)

  useEffect(() => {
    fetch(`/api/posts/${slug}`).then(r => r.json()).then(setPost)
  }, [slug])

  if (!post) return <Spinner />
  return <h1>{post.title}</h1>  // Not in initial HTML
}
```

```tsx
// GOOD: Heading in initial HTML from server
async function BlogPost({ params }: { params: { slug: string } }) {
  const post = await getPost(params.slug)  // Runs on server
  return <h1>{post.title}</h1>  // In initial HTML
}
```

### Problem: Meta tags set via useEffect

```tsx
// BAD: title set client-side — bots see default title
useEffect(() => {
  document.title = post.title
}, [post])

// GOOD: Next.js metadata export (server-rendered)
export async function generateMetadata({ params }) {
  const post = await getPost(params.slug)
  return { title: post.title }
}
```

### Problem: Pagination via JavaScript

```tsx
// BAD: Next page loads via JS — no crawlable link
<button onClick={() => setPage(p => p + 1)}>Next</button>

// GOOD: Crawlable href
<a href={`/blog?page=${page + 1}`}>Next</a>
// Or rel="next" pagination
```

### Problem: Infinite scroll without URL update

```tsx
// BAD: Infinite scroll — content only discoverable via scroll
// Googlebot doesn't scroll

// GOOD: Infinite scroll + accessible URLs
// Load more via AJAX but keep URL pagination for crawlers:
// /search?page=1 → /search?page=2 → etc.
// Link to next page at the bottom for crawlers
<a href={`/search?page=${page + 1}`} className="sr-only">Next page</a>
```

## Core Web Vitals and JS

JavaScript execution blocks rendering, affecting LCP and INP:

```tsx
// Defer non-critical scripts
<Script src="/analytics.js" strategy="lazyOnload" />
<Script src="/chat-widget.js" strategy="lazyOnload" />

// Use Suspense boundaries to prevent blocking initial render
<Suspense fallback={<Skeleton />}>
  <HeavyComponent />
</Suspense>
```

## Dynamic Routes Crawling

For dynamic routes, ensure they're discoverable:

```ts
// Generate a sitemap that lists all dynamic pages
export async function generateSitemaps() {
  const posts = await getAllPosts()  // Fetch all slugs
  return posts.map(post => ({
    url: `https://example.com/blog/${post.slug}`,
    lastModified: post.updatedAt,
  }))
}
```

## Internal Linking in JS Apps

SPA navigation uses client-side routing — without server-side rendering, bots follow `<a href>` only:

```tsx
// GOOD: Use Next.js <Link> — renders as <a href> in HTML
import Link from 'next/link'
<Link href="/about">About</Link>

// BAD for SEO: programmatic navigation without visible link
router.push('/about')  // No crawlable link
```

## Key Rules

- SEO-critical content (title, heading, body text, meta) must be in the initial server-rendered HTML.
- Test with `curl` — if the heading isn't there, Bing and other bots won't see it.
- Dynamic content for users is fine; product descriptions, blog text, and headings must be SSR.
- Pagination links must be `<a href>` — JavaScript `onClick` next-page buttons are invisible to crawlers.
