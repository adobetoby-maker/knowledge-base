# Next.js Error Handling — App Router Patterns

## Error Hierarchy in App Router

Next.js App Router has four layers of error handling, each catching different failure modes:

1. **error.tsx**: Catches runtime errors in a route segment and its children
2. **not-found.tsx**: Renders when `notFound()` is called or no route matches
3. **global-error.tsx**: Catches errors in the root layout (rare; use sparingly)
4. **Catch boundaries in Route Handlers**: API-layer error handling via try/catch

## error.tsx Structure

```typescript
// app/blog/error.tsx
'use client'  // error.tsx MUST be a client component

import { useEffect } from 'react'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    // Log to error tracking
    console.error(error)
  }, [error])

  return (
    <div>
      <h2>Something went wrong</h2>
      <button onClick={() => reset()}>Try again</button>
    </div>
  )
}
```

The `reset()` function re-renders the segment. This is useful for transient failures (network hiccup, temporary DB unavailability). Do not show a reset button for errors that will reliably repeat.

## not-found.tsx

```typescript
// app/blog/[slug]/not-found.tsx
export default function NotFound() {
  return (
    <div>
      <h2>Article not found</h2>
      <p>The article you're looking for doesn't exist.</p>
    </div>
  )
}
```

Trigger it from a Server Component:
```typescript
import { notFound } from 'next/navigation'

export default async function BlogPost({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const article = articles.find(a => a.slug === slug)
  
  if (!article) notFound()  // throws internally, caught by not-found.tsx
  
  return <ArticleLayout article={article} />
}
```

## Route Handler Error Pattern

```typescript
// app/api/invoices/route.ts
export async function POST(req: Request) {
  try {
    const body = await req.json()
    const result = schema.safeParse(body)
    
    if (!result.success) {
      return Response.json(
        { error: 'Invalid input', details: result.error.flatten() },
        { status: 400 }
      )
    }
    
    const invoice = await createInvoice(result.data)
    return Response.json(invoice, { status: 201 })
    
  } catch (error) {
    // Log here, return generic error to client
    console.error('Invoice creation failed:', error)
    return Response.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
```

Never expose raw error messages or stack traces to clients. Log the full error server-side; return a generic message client-side.

## Distinguishing Error Types

```typescript
// Operational errors (expected, handle gracefully)
if (!user) return Response.json({ error: 'Not found' }, { status: 404 })
if (!hasPermission) return Response.json({ error: 'Forbidden' }, { status: 403 })

// Validation errors (client mistake, tell them what's wrong)
if (!result.success) return Response.json({ errors: result.error.flatten() }, { status: 400 })

// Programming errors (should not happen, log and return 500)
catch (error) {
  logger.error(error)
  return Response.json({ error: 'Internal error' }, { status: 500 })
}
```

## Supabase Error Handling

Supabase returns `{ data, error }` — always check both:

```typescript
const { data: user, error } = await supabase.from('users').select('*').eq('id', id).single()

if (error) {
  if (error.code === 'PGRST116') {
    // No rows returned — expected case, not an error
    notFound()
  }
  // Unexpected error
  throw new Error(`Database error: ${error.message}`)
}

// data is guaranteed non-null here
```

`PGRST116` = "No rows returned by query expecting a single row" — this is the most common code to handle explicitly.

## Client-Side Error Boundaries

For client components with complex async logic, React's error boundary (via a library or manual class component) catches render errors:

```typescript
// Minimal error boundary
import { ErrorBoundary } from 'react-error-boundary'

<ErrorBoundary fallback={<ErrorFallback />}>
  <ComplexClientComponent />
</ErrorBoundary>
```

Use `react-error-boundary` package for modern ergonomics — it's the recommended approach over manual class components.
