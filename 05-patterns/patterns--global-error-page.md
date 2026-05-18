# Pattern: Global Error Page

## What This Solves

React's error boundary system catches unhandled render errors and suspense rejections. Without custom error pages, users see either a blank white screen or a cryptic stack trace. The challenge is: distinguishing segment-level errors from root-level crashes, giving users a recovery path, and reporting errors to a monitoring service — all without leaking internals in production.

## error.tsx vs global-error.tsx

`error.tsx` handles errors within a layout segment. It still renders inside the root `layout.tsx`, so the shell (nav, fonts, theme) remains intact. Use it for almost every route segment.

`global-error.tsx` handles errors thrown by the root `layout.tsx` itself — a much rarer failure. It renders a completely bare page and must include its own `<html>` and `<body>`. Do not put branding-heavy markup here; keep it simple and functional.

```tsx
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
    <html lang="en">
      <body>
        <div style={{ padding: '2rem', fontFamily: 'system-ui' }}>
          <h1>Something went wrong</h1>
          <button onClick={reset}>Try again</button>
        </div>
      </body>
    </html>
  )
}
```

## Segment-Level error.tsx

```tsx
// app/(dashboard)/error.tsx
'use client'
import { useEffect } from 'react'
import { captureException } from '@sentry/nextjs'

export default function DashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    captureException(error)
  }, [error])

  return (
    <div className="flex flex-col items-center justify-center min-h-[50vh] gap-4 p-8">
      <div className="text-center space-y-2">
        <h2 className="text-xl font-semibold">Something went wrong</h2>
        <p className="text-muted-foreground text-sm max-w-md">
          We've been notified and are looking into it.
        </p>
        {process.env.NODE_ENV === 'development' && (
          <pre className="mt-4 text-left text-xs bg-destructive/10 text-destructive p-4 rounded overflow-auto max-w-xl">
            {error.message}
            {'\n'}
            {error.stack}
          </pre>
        )}
      </div>
      <div className="flex gap-3">
        <button
          onClick={reset}
          className="px-4 py-2 bg-primary text-primary-foreground rounded-md text-sm"
        >
          Try again
        </button>
        <a
          href="/"
          className="px-4 py-2 border rounded-md text-sm"
        >
          Go home
        </a>
      </div>
    </div>
  )
}
```

## The reset() Function

`reset()` attempts to re-render the segment by clearing the error boundary state and re-mounting the children. It does NOT re-fetch data or restart network requests — that happens naturally as components mount again. If the error was transient (network blip, race condition), reset recovers cleanly. If the error is deterministic (bad data, missing env var), reset will fail again immediately. Give the user a "Go home" escape hatch for that case.

## Sentry Integration

Sentry's `captureException` in `useEffect` fires once on first render of the error boundary. The `error.digest` prop is a server-generated hash that ties the client error to the server-side error log — include it in the Sentry context:

```tsx
useEffect(() => {
  captureException(error, {
    extra: { digest: error.digest },
  })
}, [error])
```

For `global-error.tsx`, Sentry's Next.js SDK also hooks `instrumentation.ts` automatically, so you may get double-reporting. Filter on `error.digest` on the Sentry side.

## Development vs Production Display

Never show stack traces in production. Gate on `process.env.NODE_ENV === 'development'`. In production, show the `error.digest` value (a short hash like `2345678901`) so users can report it and support can find the corresponding server log.

## Why Not Catch in Route Handlers?

Route Handlers that throw return 500 responses — those don't trigger `error.tsx`. Error boundaries only fire for rendering errors and thrown promises. If a Server Component fetches data and the fetch throws, that triggers the boundary. Use this to your advantage: let Server Component fetches throw naturally instead of returning null, so the error boundary surfaces the failure rather than silently showing empty UI.

## Key Rules

- Use `error.tsx` in every layout segment that has important fallback logic; reserve `global-error.tsx` for root layout failures only
- Always call `captureException(error)` inside `useEffect`, not in render
- Show stack traces only when `NODE_ENV === 'development'`
- Always provide both a `reset()` button and a "Go home" link — never leave the user with only one option
- Include `error.digest` in production error messages so users can reference it with support
- `global-error.tsx` must include its own `<html>` and `<body>` tags — it replaces the root layout entirely
