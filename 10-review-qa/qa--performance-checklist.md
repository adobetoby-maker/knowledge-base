# QA: Performance Checklist

## Overview

Performance review targets Core Web Vitals: LCP (Largest Contentful Paint < 2.5s), CLS (Cumulative Layout Shift < 0.1), INP (Interaction to Next Paint < 200ms), and TTFB (Time to First Byte < 800ms). These are both UX metrics and Google ranking factors.

## LCP — Largest Contentful Paint

```tsx
// Hero images must be priority-loaded
<Image
  src="/hero.jpg"
  alt="Hero image"
  priority              // Disables lazy loading, adds preload link
  width={1200}
  height={600}
/>

// Self-host web fonts to eliminate third-party render blocking
// In Next.js, use next/font
import { Inter } from 'next/font/google'
const inter = Inter({ subsets: ['latin'], display: 'swap' })
```

```html
<!-- Preload LCP image in <head> for non-Next.js -->
<link rel="preload" as="image" href="/hero.jpg" fetchpriority="high" />
```

Common LCP causes:
- Hero image loaded lazily (use `priority` on Next.js Image)
- Render-blocking fonts (use `font-display: swap` or next/font)
- Server-rendered content blocked by slow API (use Suspense + streaming)

## CLS — Cumulative Layout Shift

```tsx
// Always specify dimensions on images
// BAD — browser doesn't know height until image loads = shift
<img src="/photo.jpg" className="w-full" />

// GOOD — browser reserves space
<img src="/photo.jpg" width={800} height={400} className="w-full" />

// For Next.js Image with unknown aspect ratio
<Image src={src} fill className="object-cover" />  // Container must be relative with height

// Avoid injecting content above existing content
// Announcement banners that appear after hydration cause CLS
// Fix: render with SSR or reserve space with min-height
```

Dynamic height elements (ads, embeds, expanded accordions) should expand downward, not push content up.

## INP — Interaction to Next Paint

```tsx
// Long tasks block the main thread — use useDeferredValue
function SearchResults({ query }: { query: string }) {
  const deferredQuery = useDeferredValue(query)
  const results = useExpensiveFilter(deferredQuery)
  return <ResultList results={results} isPending={query !== deferredQuery} />
}

// Virtualize long lists
import { useVirtualizer } from '@tanstack/react-virtual'
// Renders only visible rows instead of all 10,000

// Defer non-critical JS
const HeavyChart = dynamic(() => import('./Chart'), {
  loading: () => <ChartSkeleton />,
})
```

## TTFB — Time to First Byte

```ts
// Cache slow database queries
import { unstable_cache } from 'next/cache'

const getCachedProducts = unstable_cache(
  async (categoryId: string) => db.select().from(products).where(eq(products.categoryId, categoryId)),
  ['products-by-category'],
  { revalidate: 300 }  // 5-minute cache
)

// Use ISR for pages that don't need real-time data
export const revalidate = 60  // Regenerate every minute
```

## Bundle Size Audit

```bash
# Analyze bundle
npx @next/bundle-analyzer

# Find large dependencies
npx bundlephobia-cli lodash
# → lodash: 72.5 kB (24.5 kB gzip)
# → lodash-es: 69.1 kB (24.3 kB gzip) — no improvement for tree-shaking

# Use date-fns/esm for tree-shaking instead of moment (329 kB)
# Use lucide-react/individual imports, not barrel
import { Search } from 'lucide-react'  // Tree-shaken
// NOT: import * as Icons from 'lucide-react'  // Imports all icons
```

## Image Optimization

```tsx
// Use Next.js Image component for automatic optimization
import Image from 'next/image'

// External images need config in next.config.ts
// images: { remotePatterns: [{ protocol: 'https', hostname: 'cdn.example.com' }] }

// WebP/AVIF served automatically — no manual conversion needed
// Sizes prop for responsive images
<Image
  src="/team-photo.jpg"
  alt="Team"
  width={800}
  height={400}
  sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
/>
```

## JavaScript Loading

```tsx
// Defer analytics and non-critical scripts
import Script from 'next/script'

<Script
  src="https://www.googletagmanager.com/gtm.js?id=GTM-XXXXX"
  strategy="lazyOnload"  // Load after page is interactive
/>

// Inline critical CSS — avoid @import in CSS (blocks rendering)
// Use CSS modules or Tailwind (both inline-safe)
```

## Performance Audit Commands

```bash
# Lighthouse in CI
npx lighthouse https://your-app.com --output json --output-path ./lighthouse-report.json

# Core Web Vitals thresholds
# LCP: < 2.5s (good), < 4.0s (needs improvement), > 4.0s (poor)
# CLS: < 0.1 (good), < 0.25 (needs improvement), > 0.25 (poor)
# INP: < 200ms (good), < 500ms (needs improvement), > 500ms (poor)

# Bundle size
npx next build && npx next-bundle-analyzer
```

## Key Rules

- `priority` on the hero `<Image>` is the single most impactful LCP fix — it's one attribute.
- Specify width/height on every `<img>` — missing dimensions are the most common cause of CLS.
- Virtualize lists over 100 items — rendering 5,000 DOM nodes causes long tasks and poor INP.
- `unstable_cache` (Next.js) or Redis caching for slow DB queries is the primary TTFB fix.
- `strategy="lazyOnload"` for analytics scripts — they don't need to run before the user can interact.
