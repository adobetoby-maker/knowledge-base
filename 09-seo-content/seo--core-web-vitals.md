# SEO: Core Web Vitals

## Overview

Core Web Vitals are Google's user experience metrics that directly affect search rankings. The three metrics are LCP (Largest Contentful Paint), INP (Interaction to Next Paint), and CLS (Cumulative Layout Shift). Failing any one of them puts the page in the "poor" tier for that signal.

## The Three Metrics

### LCP (Largest Contentful Paint) — Loading

Measures: How long until the largest visible element is rendered.

| Score | Threshold |
|-------|-----------|
| Good | ≤ 2.5s |
| Needs Improvement | 2.5s – 4.0s |
| Poor | > 4.0s |

The "largest element" is usually: hero image, above-fold heading text, or background image.

### INP (Interaction to Next Paint) — Interactivity

Replaced FID in March 2024. Measures: worst interaction delay across the entire page visit.

| Score | Threshold |
|-------|-----------|
| Good | ≤ 200ms |
| Needs Improvement | 200ms – 500ms |
| Poor | > 500ms |

### CLS (Cumulative Layout Shift) — Visual Stability

Measures: how much the page jumps around during load.

| Score | Threshold |
|-------|-----------|
| Good | ≤ 0.1 |
| Needs Improvement | 0.1 – 0.25 |
| Poor | > 0.25 |

## Fixing LCP

### 1. Preload the LCP Image

```html
<!-- In <head> — tells browser to fetch this immediately -->
<link rel="preload" as="image" href="/hero-image.jpg" fetchpriority="high" />
```

In Next.js:
```tsx
import Image from 'next/image'

// The hero image should have priority={true}
<Image
  src="/hero-image.jpg"
  alt="Hero"
  width={1200}
  height={600}
  priority  // Adds fetchpriority="high" and preload link
/>
```

### 2. Serve Images in WebP/AVIF

Next.js `<Image>` does this automatically. For static HTML:
```bash
# Convert at build time
cwebp hero-image.jpg -o hero-image.webp -q 85
```

### 3. Use a CDN

Origin server latency adds directly to LCP. Cloudflare or Vercel Edge Network puts assets <50ms from users worldwide.

### 4. Don't Block Rendering with Large JavaScript

```html
<!-- Bad: blocks HTML parsing -->
<script src="heavy-bundle.js"></script>

<!-- Good: deferred loading -->
<script src="heavy-bundle.js" defer></script>
```

## Fixing CLS

### 1. Always Set Image Dimensions

```tsx
// Bad: browser doesn't know height until image loads → layout shift
<img src="photo.jpg" />

// Good: browser reserves space immediately
<img src="photo.jpg" width={800} height={400} />

// Or CSS aspect ratio
<img src="photo.jpg" style={{ aspectRatio: '2/1', width: '100%' }} />
```

### 2. Reserve Space for Dynamic Content

```tsx
// Bad: content loads after, pushes everything down
function AdSlot() {
  const [ad, setAd] = useState(null)
  return <div>{ad}</div>  // Height is 0 until ad loads
}

// Good: reserve space
function AdSlot() {
  const [ad, setAd] = useState(null)
  return (
    <div style={{ minHeight: 250 }}>  {/* Standard ad unit height */}
      {ad}
    </div>
  )
}
```

### 3. Avoid Inserting Content Above Existing Content

Banners, cookie notices, and sticky headers that appear after page load push content down. Place them at the bottom of the screen or in a space that was always reserved.

### 4. Fonts Without Layout Shift

```css
@font-face {
  font-family: 'MyFont';
  font-display: optional;  /* Prevents FOUT/layout shift */
}
```

`font-display: optional` uses the font only if it loads quickly. Prevents text reflowing when a web font replaces the fallback.

## Fixing INP

### 1. Break Up Long Tasks

JavaScript tasks >50ms block the main thread. Long tasks during interactions cause high INP:

```ts
// Bad: single long synchronous task
function processAllItems() {
  items.forEach(item => heavyComputation(item))
}

// Good: yield to browser between chunks
async function processAllItems() {
  for (const item of items) {
    heavyComputation(item)
    await scheduler.yield()  // Or: await new Promise(r => setTimeout(r, 0))
  }
}
```

### 2. Defer Non-Critical Work

```ts
// After user interaction, do critical work immediately, defer the rest
function handleButtonClick() {
  updateUI()  // Must be immediate (part of INP)
  
  // Defer analytics, logging, secondary updates
  setTimeout(() => {
    trackEvent('button_clicked')
    syncToServer()
  }, 0)
}
```

### 3. React: Wrap Non-Urgent State Updates in startTransition

```tsx
import { startTransition, useState } from 'react'

function SearchInput() {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState([])

  function handleChange(value: string) {
    setQuery(value)  // Urgent: update input immediately
    
    startTransition(() => {
      setResults(search(value))  // Non-urgent: can be interrupted
    })
  }
}
```

## Measuring

```bash
# Lighthouse (simulated)
npx lighthouse https://your-site.com --output=json --only-categories=performance

# PageSpeed Insights (field data from real users)
# Use: https://pagespeed.web.dev

# Chrome DevTools
# Performance panel → Web Vitals checkbox
```

Field data (from real users) matters more for ranking than lab data. PageSpeed Insights shows both. Focus on field data improvements.
