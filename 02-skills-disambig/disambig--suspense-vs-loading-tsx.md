# Disambiguation: Suspense vs loading.tsx

## Two Different Loading Mechanisms

Both show loading states in Next.js App Router, but they serve different purposes and operate at different granularities.

## `loading.tsx` — Route-Level

`loading.tsx` is a special file that shows immediately while the whole route (page.tsx) is being generated. It wraps the entire page in a `<Suspense>` boundary automatically.

```
Route request arrives
  ↓
loading.tsx shows immediately (no wait)
  ↓
page.tsx finishes rendering (server-side)
  ↓
Replace loading.tsx with page content
```

```typescript
// app/(admin)/invoices/loading.tsx
// Shown for the ENTIRE invoices route while page.tsx renders
export default function InvoicesLoading() {
  return (
    <div className="space-y-4">
      <div className="h-8 w-32 bg-muted animate-pulse rounded" />
      <TableSkeleton rows={5} />
    </div>
  )
}
```

Use `loading.tsx` when: the whole page needs to load before showing anything.

## `<Suspense>` — Component-Level

`<Suspense>` boundaries allow SECTIONS of a page to load independently. Different sections can resolve at different times — faster content shows first.

```typescript
// app/(admin)/dashboard/page.tsx
export default function DashboardPage() {
  return (
    <div className="grid grid-cols-3 gap-4">
      {/* Stats load immediately (fast query): */}
      <Suspense fallback={<StatsSkeleton />}>
        <DashboardStats />
      </Suspense>
      
      {/* Recent invoices load separately (slower query): */}
      <div className="col-span-3">
        <Suspense fallback={<ListSkeleton />}>
          <RecentInvoices />
        </Suspense>
      </div>
      
      {/* Chart loads last (heaviest query): */}
      <div className="col-span-3">
        <Suspense fallback={<ChartSkeleton />}>
          <RevenueChart />
        </Suspense>
      </div>
    </div>
  )
}
```

Each `<Suspense>` boundary streams independently — `DashboardStats` renders as soon as its data arrives, without waiting for `RecentInvoices`.

## When to Use Each

| Scenario | Use |
|---|---|
| Simple page, loads as a unit | `loading.tsx` |
| Dashboard with multiple independent sections | `<Suspense>` per section |
| Page shell + slow data section | `loading.tsx` + `<Suspense>` |
| Component used in multiple places that fetches its own data | `<Suspense>` around it at each usage |
| Admin list page (table + filters, simple) | `loading.tsx` is fine |

## Combining Both

They work together well:

```
Route arrives
  ↓
loading.tsx shows (page shell skeleton)
  ↓
page.tsx starts rendering
  ↓
Fast sections (Stats) resolve → show immediately
  ↓
Slow sections (Chart) still loading → show Suspense fallback
  ↓
Chart data arrives → replace fallback with chart
```

## `loading.tsx` for Nested Layouts

`loading.tsx` can exist in any route segment and applies to that segment's page only:

```
app/
  (admin)/
    loading.tsx       ← applies to ALL admin pages
    invoices/
      loading.tsx     ← overrides for invoices specifically
      page.tsx
    dashboard/
      page.tsx        ← uses the parent (admin) loading.tsx
```

## Key Difference Summary

- `loading.tsx` = automatic Suspense wrapper around the entire route's page content
- `<Suspense>` = explicit wrapper around specific components within a page
- Use `loading.tsx` for the entry point; use `<Suspense>` inside the page for granular streaming
