# Loading States Pattern

## The Three Loading Approaches

1. **Skeleton** — placeholder shapes that mimic real content layout
2. **Spinner/Loader** — generic loading indicator for actions
3. **Progressive reveal** — show cached/partial data while fresh data loads

## Skeleton Loading (Preferred for Page Content)

Match the skeleton shape to the real content — this prevents layout shift when content loads:

```typescript
// components/InvoiceTableSkeleton.tsx
export function InvoiceTableSkeleton({ rows = 5 }: { rows?: number }) {
  return (
    <div className="space-y-3">
      {/* Header skeleton */}
      <div className="flex justify-between items-center">
        <Skeleton className="h-8 w-32" />
        <Skeleton className="h-9 w-28" />
      </div>
      
      {/* Table skeleton */}
      <div className="rounded-md border">
        <div className="border-b p-4 flex gap-4">
          <Skeleton className="h-4 w-24" />
          <Skeleton className="h-4 w-32" />
          <Skeleton className="h-4 w-16" />
          <Skeleton className="h-4 w-20" />
        </div>
        {Array.from({ length: rows }).map((_, i) => (
          <div key={i} className="p-4 flex gap-4 border-b last:border-0">
            <Skeleton className="h-4 w-20" />
            <Skeleton className="h-4 w-36" />
            <Skeleton className="h-6 w-16 rounded-full" />
            <Skeleton className="h-4 w-16" />
          </div>
        ))}
      </div>
    </div>
  )
}
```

```typescript
// In Suspense boundary or loading.tsx:
<Suspense fallback={<InvoiceTableSkeleton rows={10} />}>
  <InvoiceTable />
</Suspense>
```

## Spinner for Actions (Not Page Load)

Spinners are for user-initiated actions (form submit, button click) — not for initial page load:

```typescript
// In a button:
<Button disabled={isPending}>
  {isPending ? (
    <>
      <Loader2 className="h-4 w-4 mr-2 animate-spin" />
      Saving...
    </>
  ) : (
    'Save Changes'
  )}
</Button>

// Full page action overlay (for critical operations):
{isPending && (
  <div className="fixed inset-0 bg-background/50 backdrop-blur-sm z-50 flex items-center justify-center">
    <div className="bg-card rounded-lg p-6 flex items-center gap-3">
      <Loader2 className="h-5 w-5 animate-spin" />
      <span>Processing payment...</span>
    </div>
  </div>
)}
```

## useTransition for Non-Blocking Loading

`useTransition` marks state updates as non-urgent — the UI stays interactive during the transition:

```typescript
const [isPending, startTransition] = useTransition()

function handleFilterChange(value: string) {
  startTransition(() => {
    setFilter(value)  // navigation or state update
  })
}

// Show pending state in the table while new data loads:
<div className={cn('transition-opacity', isPending && 'opacity-50 pointer-events-none')}>
  <DataTable data={data} columns={columns} />
</div>
```

## Skeleton Design Rules

1. **Match proportions**: Skeleton should be the same height/width as the real content
2. **Animate**: Use `animate-pulse` (from Tailwind/shadcn) — signals "loading" to users
3. **Don't over-detail**: Rough shapes work better than pixel-perfect skeletons
4. **Layer structure**: Preserve the overall layout — header, list, pagination

```typescript
// shadcn Skeleton component:
import { Skeleton } from '@/components/ui/skeleton'

// Basic usage:
<Skeleton className="h-4 w-[250px]" />        // text line
<Skeleton className="h-12 w-12 rounded-full" /> // avatar
<Skeleton className="h-32 w-full rounded-lg" /> // card/image
```

## Stale-While-Revalidate Pattern

Show cached data immediately, refresh in background:

```typescript
// With TanStack Query:
const { data, isFetching } = useQuery({
  queryKey: ['invoices'],
  queryFn: fetchInvoices,
  staleTime: 30 * 1000,  // data is fresh for 30s
})

// `isFetching` is true during background refresh
// `isLoading` is true only on first load
{isFetching && <div className="text-xs text-muted-foreground">Refreshing...</div>}
```

## Loading Best Practices

- Show skeletons for page content (keeps layout stable)
- Show spinners for button actions (inline feedback)
- Preserve existing content during filter/sort changes (use opacity, not replace with skeleton)
- Never show a spinner AND a skeleton at the same time
- Loading state for < 200ms: don't show anything (prevents flicker)

```typescript
// Avoid flicker for fast operations:
const [showLoading, setShowLoading] = useState(false)
const timerRef = useRef<NodeJS.Timeout>()

useEffect(() => {
  if (isPending) {
    timerRef.current = setTimeout(() => setShowLoading(true), 200)
  } else {
    clearTimeout(timerRef.current)
    setShowLoading(false)
  }
  return () => clearTimeout(timerRef.current)
}, [isPending])
```
