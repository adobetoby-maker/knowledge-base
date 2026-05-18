# Page Speed for SEO

## Why Speed Matters for Rankings

Google uses Core Web Vitals (CWV) as a ranking signal. Beyond rankings, speed affects conversion: a 1-second delay reduces conversions by ~7% for local service businesses.

**Core Web Vitals targets:**
- LCP (Largest Contentful Paint): < 2.5 seconds
- INP (Interaction to Next Paint): < 200 milliseconds
- CLS (Cumulative Layout Shift): < 0.1

## Measuring Speed

```bash
# Lighthouse in terminal
npx lighthouse https://jrsautorepair.worker-bee.app --output=json --quiet | jq '.categories.performance.score'

# Or use the Chrome DevTools MCP
# Or use Google PageSpeed Insights API
```

The most valuable measurements come from real user data (Chrome UX Report / CrUX), not lab tests. CrUX data is accessible in Google Search Console.

## LCP Optimization

LCP is usually the hero image or H1 text.

**For images (most common LCP element):**
```typescript
// Add priority={true} to ONLY the LCP image — nothing else
<Image
  src="/hero-oil-change.jpg"
  alt="Oil change service Twin Falls"
  priority={true}   // preloads this image
  width={1200}
  height={630}
/>
```

**Preconnect to critical third-party origins:**
```typescript
// app/layout.tsx
export default function Layout({ children }) {
  return (
    <html>
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
      </head>
      <body>{children}</body>
    </html>
  )
}
```

## CLS Optimization

CLS measures unexpected layout shifts. Common causes and fixes:

**Images without dimensions:**
```typescript
// CAUSES CLS: image renders, layout shifts
<img src="/photo.jpg" />

// PREVENTS CLS: space reserved for image
<Image src="/photo.jpg" width={800} height={600} alt="..." />
// or with fill + aspect-ratio container:
<div style={{ aspectRatio: '4/3' }}>
  <Image src="/photo.jpg" fill alt="..." />
</div>
```

**Fonts causing FOUT (Flash of Unstyled Text):**
```typescript
// next/font loads font at build time and inlines it — no CLS
import { Inter } from 'next/font/google'
const inter = Inter({ subsets: ['latin'] })

export default function Layout({ children }) {
  return <html className={inter.className}>{children}</html>
}
```

Never load Google Fonts via `<link>` in the head — use `next/font/google` instead.

## INP Optimization

INP measures response to user interaction. For local business sites, this is rarely a problem. If it is:
- Don't block the main thread with large JavaScript bundles
- Use `useTransition` to keep UI responsive during Server Actions
- Lazy-load non-critical components with `next/dynamic`

## JavaScript Bundle Size

```bash
# Analyze bundle
ANALYZE=true npm run build
# Opens interactive bundle visualization
```

Common bundle bloat culprits:
- Moment.js (replace with `date-fns` or `Intl.DateTimeFormat`)
- Large icon libraries (import only what you use: `import { Sun } from 'lucide-react'`)
- Chart libraries loaded on every page (lazy-load to the page that needs them)

```typescript
// Lazy-load heavy components
import dynamic from 'next/dynamic'
const HeavyChart = dynamic(() => import('@/components/HeavyChart'), {
  loading: () => <div>Loading chart...</div>,
})
```

## Image Optimization Checklist

1. Use `next/image` for all images — automatic WebP/AVIF conversion
2. Set `sizes` attribute to prevent downloading oversized images:
   ```typescript
   <Image sizes="(max-width: 768px) 100vw, 50vw" ... />
   ```
3. Use `priority` on ONLY the above-the-fold LCP image
4. Use `placeholder="blur"` + `blurDataURL` for smooth loading
5. Compress images before upload: target < 200KB for hero images

## Cloudflare Workers Image Handling

On `climb-brasil` (CF Workers), `next/image` optimization requires:
```typescript
// In the route or component that uses image optimization
export const runtime = 'nodejs'
```

Without this, Cloudflare Workers runtime can't execute Sharp (the image processor). Alternatively, serve pre-optimized images from R2 or use Cloudflare Images service.

## Font Loading Strategy

```typescript
// Good: next/font/google (zero layout shift, self-hosted)
import { Inter, Roboto_Mono } from 'next/font/google'

// Bad: @import in CSS (render-blocking, external request)
// @import url('https://fonts.googleapis.com/...')
```

For local fonts:
```typescript
import localFont from 'next/font/local'
const myFont = localFont({
  src: './fonts/MyFont.woff2',
  variable: '--font-my-font',
})
```

## Caching Headers for Static Assets

Next.js sets optimal caching headers for static assets automatically (`/_next/static/`). For custom assets in `public/`:
```typescript
// next.config.ts
export default {
  async headers() {
    return [
      {
        source: '/images/:path*',
        headers: [
          { key: 'Cache-Control', value: 'public, max-age=31536000, immutable' },
        ],
      },
    ]
  },
}
```
