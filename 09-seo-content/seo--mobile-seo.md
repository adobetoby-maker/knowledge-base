# SEO: Mobile SEO

## What This Solves

Google uses mobile-first indexing — the mobile version of your page is what Google crawls and indexes, regardless of how the desktop looks. If the mobile experience is poor (small text, blocked content, slow load), rankings suffer even for desktop searchers.

## Core Mobile Requirements

**Viewport meta tag** (must be present in every page):
```html
<meta name="viewport" content="width=device-width, initial-scale=1" />
```
Next.js includes this by default in the `<html>` response. Verify it's not being overridden.

**Text size**: minimum 16px body text on mobile. 14px is the practical floor.

**Tap targets**: minimum 44×44px for any interactive element. Buttons, links, form fields. Small targets cause mis-taps which increase bounce rate.

**Content not blocked**: No CSS `display: none` on mobile for content that's visible on desktop. Google's mobile crawler won't see hidden content.

## Core Web Vitals for Mobile

Mobile CWV scores are typically worse than desktop due to slower CPUs and networks. Google's threshold:

| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| LCP | < 2.5s | 2.5–4.0s | > 4.0s |
| INP | < 200ms | 200–500ms | > 500ms |
| CLS | < 0.1 | 0.1–0.25 | > 0.25 |

Check field data (real users), not just lab data. Use: Google Search Console → Core Web Vitals report.

## LCP Optimization for Mobile

The Largest Contentful Paint is usually the hero image. On mobile:

```tsx
// Hero image: use priority to preload
<Image
  src="/hero.jpg"
  alt="JR's Auto Repair Twin Falls"
  fill
  priority     // Adds <link rel="preload"> in <head>
  sizes="100vw"
  className="object-cover"
/>
```

Also: compress hero images to under 200KB for mobile. Use WebP.

## Avoid Intrusive Interstitials

Google penalizes interstitials that block content on mobile:
- Cookie banners that cover the full page ✗ (use banner-style bottom bar ✓)
- Login gates covering content ✗
- Full-page app install prompts ✗

Acceptable interstitials:
- Age verification for regulated content
- Legal notices required by law
- Login walls where content is clearly behind a paywall

## Mobile Navigation Patterns

```tsx
// Hamburger menu — accessible
<Sheet>
  <SheetTrigger asChild>
    <Button variant="ghost" size="icon" className="md:hidden" aria-label="Open menu">
      <Menu className="h-5 w-5" />
    </Button>
  </SheetTrigger>
  <SheetContent side="left" className="w-72">
    <nav>
      <NavLinks />
    </nav>
  </SheetContent>
</Sheet>
```

## Font Size Enforcement

```css
/* Prevent browser font-size adjustment */
html {
  -webkit-text-size-adjust: 100%;
  text-size-adjust: 100%;
}

/* Minimum readable text */
body {
  font-size: 16px;
  line-height: 1.5;
}

/* Never go below 14px for any body-level text */
.small-text {
  font-size: 0.875rem; /* 14px */
}
```

## Click-to-Call

On mobile, phone numbers must be tappable:
```tsx
// BAD: just text
<p>(208) 595-2101</p>

// GOOD: tappable link on mobile
<a href="tel:+12085952101" className="hover:underline">
  (208) 595-2101
</a>
```

This is both UX and a Google Business Profile ranking signal.

## Mobile-Specific Structured Data

For mobile, Google prioritizes `SiteNavigationElement` breadcrumbs:
```ts
{
  '@context': 'https://schema.org',
  '@type': 'BreadcrumbList',
  itemListElement: [
    { '@type': 'ListItem', position: 1, name: 'Home', item: 'https://jrsautorepair.com' },
    { '@type': 'ListItem', position: 2, name: 'Services', item: 'https://jrsautorepair.com/services' },
    { '@type': 'ListItem', position: 3, name: 'Brake Repair' },
  ],
}
```

## Testing Mobile SEO

1. Google Search Console → Mobile Usability report
2. PageSpeed Insights → Mobile tab (field data from real users)
3. Chrome DevTools → Device toolbar (Ctrl+Shift+M) — not a perfect proxy but catches obvious issues
4. `lighthouse --preset=perf --form-factor=mobile` in CI for regression detection
