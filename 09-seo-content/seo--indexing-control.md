# Controlling What Google Indexes

Index control is about preventing low-quality, duplicate, or sensitive pages from diluting your site's crawl budget and topical authority. Over-indexing is as harmful as under-indexing: thin pages in the index drag down the perceived quality of the entire domain.

## robots.txt Directives

`robots.txt` controls crawler access at the crawl layer — it prevents Googlebot from fetching a URL, but it does not prevent that URL from appearing in the index if other pages link to it.

```
User-agent: *
Disallow: /admin/
Disallow: /api/
Disallow: /internal/
```

Key misunderstanding: `Disallow` in robots.txt keeps the page out of Googlebot's crawl queue, but a disallowed page that receives external links can still appear as a URL-only result (without snippet) in search results. To prevent indexing of a page, you need `noindex` — which requires the page to be fetchable (not disallowed).

Don't block CSS and JavaScript in robots.txt. Googlebot needs to render those files to evaluate page quality. Blocking them causes Googlebot to see a broken page and may suppress rich results.

## noindex Meta Tag vs. X-Robots-Tag

`<meta name="robots" content="noindex">` — placed in the `<head>` of the HTML. Tells Google not to index this specific page. The page must be crawlable (not blocked by robots.txt) for Google to read this tag.

`X-Robots-Tag: noindex` — HTTP response header. Works the same way but can be applied to non-HTML resources (PDFs, images) and can be set dynamically without modifying HTML. Preferred for:
- Search result pages (`/search?q=...`): set the header in the route handler.
- User-generated content pages with thin content.
- Paginated pages past page 5 where content has no standalone search value.

Never both disallow and noindex the same page — the noindex tag can't be read if the page is blocked.

## nofollow on UGC Links

User-generated content (comments, forum posts, reviews) may contain spammy or manipulative links. Mark them:

```html
<a href="https://external-site.com" rel="nofollow ugc">link text</a>
```

`nofollow` tells Google not to follow the link for PageRank purposes. `ugc` is the more specific attribute for user-generated content — use both. This protects your domain from being penalized for outbound links you don't editorially endorse.

Automate `rel="nofollow ugc"` on all user-submitted link rendering — don't rely on manual review.

## Canonical for Near-Duplicate Pages

When multiple URLs serve very similar content (filtered product pages, pagination, UTM-tracked URLs), use the canonical tag to tell Google which version is the authoritative one:

```html
<link rel="canonical" href="https://example.com/product/blue-widget" />
```

Apply canonical on:
- Filtered/sorted variants: `/products?color=blue&sort=price` → canonical to `/products/blue-widgets`.
- UTM-tracked pages: all UTM variants canonical to the clean URL.
- `www` vs. non-`www`: pick one and canonical the other; also handle with 301 redirect.
- `http` vs. `https`: canonical to HTTPS; redirect HTTP to HTTPS.

The canonical tag is a strong hint, not a directive — Google may override it if the pages are too different or if your internal link structure contradicts it.

## URL Parameter Handling in Search Console

Search Console's legacy URL Parameters tool has been deprecated. URL parameter handling is now managed via:
1. Canonical tags on parameterized URLs (primary method).
2. robots.txt `Disallow` for parameters with no indexable value (session IDs, tracking params).
3. Consistent internal linking — always link to the canonical URL form, never to parameter variants.

## Key Rules

- `robots.txt` blocks crawling; `noindex` blocks indexing. Never block a page in robots.txt and also apply noindex — Google can't read the noindex if it can't fetch the page.
- Never block CSS and JavaScript in robots.txt.
- Apply `noindex` via HTTP header for dynamic routes; use `<meta>` tag for static HTML pages.
- All user-submitted link rendering must automatically apply `rel="nofollow ugc"`.
- Canonical tag must match what your internal links point to — inconsistency causes Google to override your canonical declaration.
- Pick one canonical URL form (www/non-www, http/https, trailing slash or not) and enforce it with 301 redirects site-wide.
