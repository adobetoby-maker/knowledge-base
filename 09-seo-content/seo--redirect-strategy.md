# SEO: Redirect Strategy

## Overview

Redirects transfer link equity, resolve URL changes, and prevent 404s. Wrong redirects (302 instead of 301, redirect chains, redirect loops) lose PageRank and confuse crawlers. Plan redirects before changing URLs — retroactive cleanup is harder.

## When to Use Each Type

| Code | Type | Use case | Link equity |
|---|---|---|---|
| 301 | Permanent | URL changed forever | Passed (~99%) |
| 302 | Temporary | A/B test, maintenance | Not passed |
| 307 | Temporary (HTTP method preserved) | Maintenance pages | Not passed |
| 308 | Permanent (HTTP method preserved) | Rare — API redirects | Passed |
| 410 | Gone | Permanently removed, no replacement | N/A |

**Default**: use 301. Use 302 only when you genuinely intend to revert the change.

## Next.js Redirects (next.config.ts)

```ts
const redirects: Redirect[] = [
  // Old blog → new blog
  {
    source: '/articles/:slug',
    destination: '/blog/:slug',
    permanent: true,  // 308 in App Router, 301 in Pages Router
  },

  // Old category pages
  {
    source: '/category/:cat',
    destination: '/topics/:cat',
    permanent: true,
  },

  // Legacy flat URL → new nested structure
  {
    source: '/checkout',
    destination: '/shop/checkout',
    permanent: false,  // Temporary while redesign is in progress
  },
]

export default { redirects: async () => redirects }
```

## Middleware Redirects (Dynamic)

For database-driven or user-specific redirects:

```ts
// middleware.ts
export async function middleware(req: NextRequest) {
  const pathname = req.nextUrl.pathname

  // Check custom redirect table
  const redirect = await getRedirect(pathname)  // Cache this!
  if (redirect) {
    return NextResponse.redirect(
      new URL(redirect.destination, req.url),
      { status: redirect.permanent ? 301 : 302 }
    )
  }
}
```

Cache redirect lookups — middleware runs on every request.

## Redirect Chains (Avoid)

```
/old → /intermediate → /final    ← 2 hops, bad
/old → /final                    ← Direct, good
```

Each hop loses some link equity and adds latency. Crawlers may stop following after 3-5 hops. Fix chains by pointing the original URL directly to the final destination.

```ts
// Flatten chains automatically
async function flattenRedirects(redirectMap: Map<string, string>): Map<string, string> {
  const flattened = new Map<string, string>()

  for (const [from, to] of redirectMap) {
    let final = to
    let hops = 0
    while (redirectMap.has(final) && hops < 10) {
      final = redirectMap.get(final)!
      hops++
    }
    flattened.set(from, final)
  }

  return flattened
}
```

## Canonicalization vs Redirect

| Scenario | Solution |
|---|---|
| Two URLs serve the same content | Canonical tag or 301 redirect |
| URL parameter variants: `/shoes?color=red` | Canonical to `/shoes` |
| Trailing slash: `/about` vs `/about/` | 301 redirect to one standard |
| WWW vs non-WWW: `www.example.com` vs `example.com` | 301 redirect to canonical form |
| HTTP vs HTTPS | 301 redirect to HTTPS |

## 410 Gone (Better Than 302 to Homepage)

```ts
// When a product is permanently discontinued
if (product.deleted) {
  return new Response(null, { status: 410 })  // Gone — remove from index
}
```

A 302 redirect to the homepage passes bad signals to Google: "this content is at the homepage" (soft 404). A 410 tells Google to remove the URL from the index.

## Monitoring Redirects

```bash
# Check redirect status
curl -I -L https://example.com/old-url

# Count hops
curl -v -L --max-redirs 10 https://example.com/old-url 2>&1 | grep "< HTTP"
```

Search Console → Coverage → Redirect errors shows crawl-time redirect issues.

## Key Rules

- 301 (permanent) unless you plan to revert. Most redirects should be permanent.
- Fix redirect chains — the final destination should be a direct 301 from the original URL.
- Never 302-redirect to the homepage for deleted content — use 410.
- Trailing slash consistency: pick `/about` or `/about/` and 301 redirect the other.
- Migrate redirects before launch, not after — every day without a redirect is lost link equity.
