# Performance Review Checklist

## Core Web Vitals Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| LCP (Largest Contentful Paint) | < 2.5s | Time until largest image/text renders |
| INP (Interaction to Next Paint) | < 200ms | Response time to user interaction |
| CLS (Cumulative Layout Shift) | < 0.1 | Layout stability (elements jumping) |

Measure at: PageSpeed Insights, Chrome DevTools Lighthouse, Vercel Analytics.

## Image Checklist

- [ ] Hero/LCP image has `priority` prop on `<Image>`
- [ ] All images have `width` and `height` props (prevents CLS)
- [ ] Images use `sizes` attribute appropriate to their display size
- [ ] Remote image domains listed in `next.config.js` `remotePatterns`
- [ ] Images below fold don't have `priority` (preserve lazy loading)
- [ ] Large images (>500KB original) compressed before serving

## Font Loading Checklist

- [ ] Fonts loaded via `next/font` (self-hosted, no external font CDN)
- [ ] `display: 'swap'` on font (prevents invisible text during load)
- [ ] No more than 2-3 font families (each adds load time)
- [ ] Variable fonts used when available (one file for all weights)

## JavaScript Bundle Checklist

- [ ] Heavy dependencies (charts, editors) loaded with `dynamic()` import
- [ ] No large libraries imported for small utilities (`import _ from 'lodash'` for one function)
- [ ] Client Components only used where interactivity is needed
- [ ] No Server Components accidentally converted to Client Components

```typescript
// Check: is this component actually interactive?
// If it only renders data with no event handlers → Server Component
// If it has onClick/onChange/useState → Client Component

// Heavy component loaded only when needed
const RichTextEditor = dynamic(() => import('@/components/rich-text-editor'), {
  loading: () => <Textarea />,  // fallback
  ssr: false,
})
```

## Data Fetching Checklist

- [ ] No N+1 queries (single query with join vs. loop of queries)
- [ ] Pagination on lists > 100 items
- [ ] Database indexes on columns used in WHERE/ORDER BY
- [ ] Supabase queries select only needed columns, not `*` for large tables

```typescript
// N+1 problem — AVOID
const invoices = await supabase.from('invoices').select('*')
const invoicesWithCustomers = await Promise.all(
  invoices.data.map(async inv => ({
    ...inv,
    customer: await supabase.from('customers').select('name').eq('id', inv.customer_id).single()
  }))
)  // 1 query + N queries = N+1

// Fixed — single query with join
const { data } = await supabase
  .from('invoices')
  .select('*, customers(name)')  // single query with join
```

## Caching Checklist

- [ ] Static pages use ISR or full static rendering
- [ ] API routes for stable data include `cache-control` headers
- [ ] `revalidatePath()` / `revalidateTag()` called after mutations
- [ ] Expensive computations memoized with `unstable_cache`

## React Performance Checklist

- [ ] Lists use stable `key` props (not array index for sortable/filterable lists)
- [ ] `useMemo` on expensive computations that depend on changing state
- [ ] `useCallback` on functions passed to child components as props
- [ ] `React.memo` on pure display components that re-render from parent

```typescript
// When does useMemo actually help?
// When: computation is genuinely expensive AND dependency changes infrequently
// When NOT: simple operations (adding numbers, filtering small arrays)

// HELPFUL — sorting thousands of items on filter change
const sortedItems = useMemo(() =>
  [...items].sort((a, b) => a.name.localeCompare(b.name)),
  [items]  // only re-sort when items change
)

// UNHELPFUL — not expensive enough to warrant memoization
const displayName = useMemo(() => `${first} ${last}`, [first, last])  // overkill
```

## Cloudflare Workers Checklist

- [ ] No N+1 D1 queries (batch instead)
- [ ] KV caching for frequently-read, rarely-changed data
- [ ] `ctx.waitUntil()` for non-critical work (analytics, logging)
- [ ] Response cached with `cf: { cacheTtl: 3600 }` for public content
