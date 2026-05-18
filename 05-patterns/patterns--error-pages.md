# Error Pages Pattern

## Next.js Special Files

| File | Purpose | When Shown |
|---|---|---|
| `not-found.tsx` | 404 page | `notFound()` called or no matching route |
| `error.tsx` | Error boundary | Uncaught error in Server Component |
| `global-error.tsx` | Root error | Error in root layout |
| `loading.tsx` | Loading state | While page.tsx loads |

## 404 Page

```typescript
// app/not-found.tsx (global 404)
import Link from 'next/link'

export default function NotFound() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center text-center px-4">
      <h1 className="text-6xl font-bold text-muted-foreground">404</h1>
      <h2 className="text-2xl font-semibold mt-4">Page not found</h2>
      <p className="text-muted-foreground mt-2 max-w-md">
        The page you're looking for doesn't exist or has been moved.
      </p>
      <Link
        href="/"
        className="mt-6 px-6 py-2 bg-primary text-primary-foreground rounded-md"
      >
        Go home
      </Link>
    </div>
  )
}
```

Calling `notFound()` from a Server Component renders this page:
```typescript
// app/blog/[slug]/page.tsx
export default async function BlogPost({ params }) {
  const { slug } = await params
  const article = articles.find(a => a.slug === slug)
  
  if (!article) notFound()  // renders not-found.tsx
  
  return <ArticleContent article={article} />
}
```

## Section-Specific 404

For the portal or admin, a custom not-found is more appropriate:
```typescript
// app/(portal)/not-found.tsx
export default function PortalNotFound() {
  return (
    <div className="flex flex-col items-center justify-center min-h-[400px] gap-4">
      <h2 className="text-xl font-semibold">Not found</h2>
      <p className="text-muted-foreground">This invoice doesn't exist or you don't have access.</p>
      <Link href="/portal/invoices">Back to invoices</Link>
    </div>
  )
}
```

## Error Page

```typescript
// app/(portal)/error.tsx
'use client'
import { useEffect } from 'react'

export default function PortalError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    // Log to error tracking
    console.error('Portal error:', error.digest, error.message)
  }, [error])

  return (
    <div className="flex flex-col items-center justify-center min-h-[400px] gap-4 text-center">
      <div className="p-3 rounded-full bg-destructive/10">
        {/* Error icon */}
      </div>
      <div>
        <h2 className="text-xl font-semibold">Something went wrong</h2>
        <p className="text-sm text-muted-foreground mt-1">
          {process.env.NODE_ENV === 'development'
            ? error.message
            : 'An unexpected error occurred'}
        </p>
      </div>
      <div className="flex gap-3">
        <button onClick={reset} className="px-4 py-2 border rounded-md text-sm">
          Try again
        </button>
        <Link href="/portal/dashboard" className="px-4 py-2 bg-primary text-primary-foreground rounded-md text-sm">
          Go to dashboard
        </Link>
      </div>
      {error.digest && (
        <p className="text-xs text-muted-foreground">Error ID: {error.digest}</p>
      )}
    </div>
  )
}
```

Show the `digest` (server-side error ID) so the user can report it. In development, show the full error message. In production, show generic text.

## Local Business 404 (jrs-auto-repair)

A 404 page is an opportunity to keep users engaged:
```typescript
// app/not-found.tsx
export default function NotFound() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center text-center px-4">
      <h1 className="text-4xl font-bold">Page Not Found</h1>
      <p className="text-muted-foreground mt-2">
        The page you're looking for doesn't exist.
      </p>
      
      {/* Keep them engaged */}
      <div className="mt-8 grid grid-cols-1 sm:grid-cols-3 gap-4 text-left max-w-lg">
        <Link href="/services" className="p-4 border rounded-lg hover:bg-accent">
          <h3 className="font-medium">Our Services</h3>
          <p className="text-sm text-muted-foreground">See what we offer</p>
        </Link>
        <Link href="/blog" className="p-4 border rounded-lg hover:bg-accent">
          <h3 className="font-medium">Auto Tips</h3>
          <p className="text-sm text-muted-foreground">Maintenance guides</p>
        </Link>
        <a href="tel:2085952101" className="p-4 border rounded-lg hover:bg-accent">
          <h3 className="font-medium">Call Us</h3>
          <p className="text-sm text-muted-foreground">(208) 595-2101</p>
        </a>
      </div>
    </div>
  )
}
```

## Maintenance Page

For planned downtime, add a `maintenance.tsx` or redirect to a static page hosted separately. Never use the database for a maintenance page — if the DB is down, the maintenance page must still load.
