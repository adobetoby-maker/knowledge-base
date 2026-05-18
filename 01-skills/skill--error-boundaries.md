# Error Boundaries

## What Error Boundaries Do

An error boundary catches JavaScript errors thrown during rendering in its subtree. Without one, an error in any component crashes the entire React tree and shows a blank page. With one, only the affected subtree shows the fallback UI.

Error boundaries do NOT catch:
- Errors in event handlers (use try/catch inside the handler)
- Async errors (errors in `setTimeout`, `fetch`, etc.)
- Errors in the error boundary component itself
- Server-side rendering errors

## Next.js App Router: `error.tsx`

In App Router, `error.tsx` files ARE error boundaries. Place them to scope the recovery:

```
app/
  error.tsx              # catches errors in root layout children
  (portal)/
    error.tsx            # catches errors only within portal routes
    invoices/
      error.tsx          # catches errors only in the invoices section
      page.tsx
```

```typescript
// app/(portal)/error.tsx
'use client'  // Error components must be Client Components

import { useEffect } from 'react'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }  // digest is a server-side error ID
  reset: () => void
}) {
  useEffect(() => {
    // Log to error tracking service
    console.error('Portal error:', error)
    // Sentry.captureException(error)
  }, [error])

  return (
    <div className="flex flex-col items-center justify-center min-h-[400px] gap-4">
      <h2 className="text-xl font-semibold">Something went wrong</h2>
      <p className="text-muted-foreground text-sm">
        {error.message || 'An unexpected error occurred'}
      </p>
      <button
        onClick={reset}
        className="px-4 py-2 bg-primary text-primary-foreground rounded-md"
      >
        Try again
      </button>
    </div>
  )
}
```

`reset()` re-renders the error boundary subtree and retries the render.

## `global-error.tsx` for Root Layout Errors

When an error occurs in the root layout, `error.tsx` cannot catch it (error boundaries can't catch errors in their own layout). Use `global-error.tsx`:

```typescript
// app/global-error.tsx
'use client'

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <html>
      <body>
        <h2>Something went wrong!</h2>
        <button onClick={reset}>Try again</button>
      </body>
    </html>
  )
}
```

`global-error.tsx` must include `<html>` and `<body>` because it replaces the root layout.

## React Error Boundary Component (Client Only)

For finer control inside Client Components, use `react-error-boundary`:
```bash
npm install react-error-boundary
```

```typescript
import { ErrorBoundary } from 'react-error-boundary'

function InvoiceChart() {
  // chart that might throw on bad data
}

function ChartFallback({ error, resetErrorBoundary }: FallbackProps) {
  return (
    <div className="p-4 border border-red-200 rounded-md">
      <p className="text-red-600 text-sm">Chart failed to load: {error.message}</p>
      <button onClick={resetErrorBoundary} className="text-sm underline mt-2">
        Retry
      </button>
    </div>
  )
}

export function Dashboard() {
  return (
    <div>
      <InvoiceList />
      <ErrorBoundary FallbackComponent={ChartFallback}>
        <InvoiceChart />
      </ErrorBoundary>
    </div>
  )
}
```

With this, a crash in `InvoiceChart` shows the fallback without affecting `InvoiceList`.

## `onReset` for Resetting State

When the error might be caused by corrupted state, clear the state on reset:
```typescript
<ErrorBoundary
  FallbackComponent={ChartFallback}
  onReset={() => {
    // Clear any state that might have caused the error
    setChartData(null)
    queryClient.invalidateQueries({ queryKey: ['chart-data'] })
  }}
>
  <InvoiceChart data={chartData} />
</ErrorBoundary>
```

## Async Errors with useQuery

React Query catches async errors and exposes them without throwing:
```typescript
const { data, error, isError } = useQuery({ queryKey: [...], queryFn: fetch })

if (isError) {
  return <div>Failed to load: {error.message}</div>
}
```

This is preferred over letting errors bubble to error boundaries for data-fetching scenarios.

## Error Boundary Placement Strategy

- **Page level** (`error.tsx`): for any error that prevents the entire page from rendering
- **Section level** (react-error-boundary around a section): for non-critical widgets like charts, analytics panels
- **Component level**: only for components that are known to be unstable (third-party charts, complex data transforms)

Don't wrap every component. Over-using error boundaries makes errors invisible and debugging harder.
