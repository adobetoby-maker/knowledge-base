# Skill: performance-optimization

**Trigger:** Site is slow — diagnosing and fixing performance issues in Next.js, React, or Cloudflare Workers apps.
**Returns:** Systematic diagnosis workflow, common fixes, and measurement approach.

## Diagnosis First

Never optimize without measuring. Before touching code:

1. Run PageSpeed Insights on the affected page
2. Identify which Core Web Vital is failing: LCP, INP, or CLS
3. Open Chrome DevTools → Performance → Record a page load
4. Identify the largest paint element (LCP), layout shifts (CLS), or slow event handlers (INP)

Optimize the actual bottleneck, not what you think the bottleneck is.

## LCP (Largest Contentful Paint) Optimization

LCP measures how long until the largest visible element paints. Usually the hero image or heading.

```typescript
// Priority load the LCP image
<Image src="/hero.jpg" alt="Hero" width={1920} height={1080} priority />
// Add priority prop to the single above-fold image. Never add it to multiple images.

// Preconnect to image CDN
<link rel="preconnect" href="https://your-cdn.com" />

// Use blur placeholder for images below fold
<Image src={url} alt={alt} placeholder="blur" blurDataURL={blurHash} />
```

Common LCP failures:
- Hero image not using `priority` prop → lazy loaded when it should load eagerly
- Image not in `remotePatterns` → falls back to unoptimized format
- Large uncompressed image → Next.js optimization fixes this automatically if configured

## CLS (Cumulative Layout Shift) Prevention

CLS measures unexpected layout movement. Always specify dimensions for images:

```typescript
// Wrong — no dimensions, browser doesn't reserve space
<Image src={url} alt="" />

// Right — browser reserves exact space
<Image src={url} alt="" width={800} height={600} />

// For fill images — parent must have explicit dimensions
<div style={{ position: 'relative', height: '400px' }}>
  <Image src={url} alt="" fill className="object-cover" />
</div>
```

Also causes CLS:
- Fonts loading late (FOUT) — fix with `next/font`
- Dynamic content injecting above existing content
- Embeds (ads, videos) without reserved space

## Bundle Size

```bash
# Analyze bundle
ANALYZE=true npm run build
# Or:
npx @next/bundle-analyzer
```

Fix large bundles:

```typescript
// Dynamic import — splits to separate chunk
const HeavyComponent = dynamic(() => import('./HeavyComponent'), {
  loading: () => <Spinner />,
  ssr: false  // also disables SSR if component uses browser APIs
})

// Date library — use date-fns not moment (moment = 200kB)
import { format } from 'date-fns'  // 2kB

// Icon libraries — import specific icons, not the whole library
import { CheckIcon } from 'lucide-react'  // not: import * from 'lucide-react'
```

## React Rendering Performance

```typescript
// useMemo — memoize expensive computation
const sortedInvoices = useMemo(() => {
  return invoices.sort((a, b) => b.amount - a.amount)
}, [invoices])

// useCallback — stable function reference for props
const handleDelete = useCallback((id: string) => {
  setItems(prev => prev.filter(item => item.id !== id))
}, [])  // empty deps — function never needs to change

// React.memo — skip re-render if props unchanged
const InvoiceRow = React.memo(function InvoiceRow({ invoice, onDelete }) {
  return <tr>...</tr>
})
```

Use these only when you've measured a performance problem. Premature memoization adds complexity without benefit.

## Database Query Performance

```typescript
// N+1 pattern — DON'T do this
for (const invoice of invoices) {
  invoice.items = await getLineItems(invoice.id)  // N database calls
}

// JOIN — DO this instead
const invoicesWithItems = await supabase
  .from('invoices')
  .select('*, line_items(*)')  // 1 database call

// Index coverage — ensure all WHERE columns are indexed
// Check with: EXPLAIN ANALYZE SELECT ... FROM invoices WHERE user_id = '...'
```

## Cloudflare Workers Performance

```typescript
// Cache expensive computations in KV
const cached = await env.KV.get('reports:2026-05-18', 'json')
if (cached) return Response.json(cached)

const data = await computeExpensiveReport()
await env.KV.put('reports:2026-05-18', JSON.stringify(data), {
  expirationTtl: 3600  // 1 hour cache
})
return Response.json(data)
```

## Streaming for Time-to-First-Byte

For slow pages, stream content as it becomes available:

```typescript
// app/dashboard/page.tsx
export default async function Dashboard() {
  return (
    <div>
      <QuickStats />  {/* renders immediately */}
      <Suspense fallback={<Spinner />}>
        <SlowDataComponent />  {/* streams in when ready */}
      </Suspense>
    </div>
  )
}
```

This dramatically improves perceived performance — user sees content immediately while heavy data loads.

## Measurement After Changes

After every optimization:
1. Run PageSpeed Insights again
2. Compare LCP, CLS, INP scores
3. Check Lighthouse in Chrome DevTools (simulated conditions, more consistent than field data)
4. Monitor Core Web Vitals in Google Search Console for real user data (takes 28 days to accumulate)
