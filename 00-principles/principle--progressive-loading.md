# Progressive Loading

## What It Means

Progressive loading means the page becomes useful before it's fully loaded. The user sees the most important content first, then secondary content loads in.

This is distinct from "show nothing until everything is ready" (bad) and "show everything at once from a full page load" (fine for static pages).

## The Loading Sequence

```
1. Page shell (layout, navigation) → immediate
2. Above-the-fold content → < 1 second
3. Visible section content → < 2 seconds
4. Below-the-fold / secondary content → background
5. Analytics, chat widgets → last
```

## Implementation in Next.js

### Layer 1: loading.tsx for Instant Shell

```typescript
// app/(portal)/invoices/loading.tsx
// Shows immediately while the Server Component renders
import { InvoiceTableSkeleton } from '@/components/InvoiceTableSkeleton'

export default function InvoicesLoading() {
  return (
    <div className="space-y-4">
      <div className="flex justify-between">
        <div className="h-8 w-32 bg-muted animate-pulse rounded" />
        <div className="h-9 w-28 bg-muted animate-pulse rounded" />
      </div>
      <InvoiceTableSkeleton />
    </div>
  )
}
```

### Layer 2: Suspense for Section-Level Streaming

```typescript
// app/(portal)/dashboard/page.tsx
import { Suspense } from 'react'

export default function DashboardPage() {
  return (
    <div className="grid grid-cols-3 gap-4">
      {/* Critical stats: load immediately */}
      <Suspense fallback={<StatCardSkeleton />}>
        <InvoiceStats />        {/* fetches count and total */}
      </Suspense>
      
      {/* Recent list: secondary */}
      <div className="col-span-3">
        <Suspense fallback={<ListSkeleton />}>
          <RecentInvoices />    {/* fetches 5 most recent */}
        </Suspense>
      </div>
    </div>
  )
}
```

Each `<Suspense>` boundary streams independently — `InvoiceStats` renders as soon as its data arrives, without waiting for `RecentInvoices`.

### Layer 3: Lazy Components (Client-Side)

```typescript
import dynamic from 'next/dynamic'

// Heavy chart component — only loads when the user scrolls to it
const InvoiceChart = dynamic(() => import('@/components/InvoiceChart'), {
  loading: () => <div className="h-64 bg-muted animate-pulse rounded" />,
})

// Non-critical: load after main content
const LiveChat = dynamic(() => import('@/components/LiveChat'), {
  loading: () => null,  // no placeholder — doesn't affect layout
  ssr: false,
})
```

## Priority Content

Mark as priority ONLY the above-the-fold LCP image:
```typescript
// The hero image on the homepage — this is the LCP element
<Image
  src="/hero-oil-change.jpg"
  alt="Professional oil change service"
  priority={true}     // preloads immediately
  width={1200}
  height={630}
/>

// All other images: no priority (lazy-loaded by default)
<Image
  src="/shop-interior.jpg"
  alt="..."
  width={800}
  height={500}
  // priority not set — loads lazily
/>
```

Adding `priority` to multiple images defeats the purpose — only the actual LCP element should be priority.

## Data Fetching Priority

Parallel data fetching in Server Components:
```typescript
// SLOW: serial — waits for each before starting next
const invoices = await fetchInvoices()
const customers = await fetchCustomers()
const stats = await fetchStats()

// FAST: parallel — all start simultaneously
const [invoices, customers, stats] = await Promise.all([
  fetchInvoices(),
  fetchCustomers(),
  fetchStats(),
])
```

Total time = max(each fetch), not sum.

## Defer Non-Critical Work

Analytics, chat widgets, and non-critical scripts should load AFTER the main content:
```typescript
// app/layout.tsx
import Script from 'next/script'

export default function Layout({ children }) {
  return (
    <html>
      <body>
        {children}
        {/* strategy="lazyOnload" defers until after page is interactive */}
        <Script
          src="https://widget.intercom.com/widget/..."
          strategy="lazyOnload"
        />
      </body>
    </html>
  )
}
```

`strategy="lazyOnload"` is the lowest priority — loads after the page is fully interactive.
