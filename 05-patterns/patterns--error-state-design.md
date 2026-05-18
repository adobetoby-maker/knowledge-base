# Pattern: Error State Design

## Overview
Error states communicate what went wrong and what the user can do next. The critical distinction is that different HTTP errors have fundamentally different causes and remedies — conflating them produces misleading UI. A retry button on a 403 is useless; a "go home" button on a 500 abandons recoverable state.

## Implementation

### Error type classification

```tsx
type AppError =
  | { type: 'not-found' }        // 404 — resource doesn't exist
  | { type: 'forbidden' }        // 403 — user lacks permission
  | { type: 'server-error' }     // 5xx — our fault
  | { type: 'network' }          // no response at all
  | { type: 'unauthorized' }     // 401 — not logged in

function ErrorState({ error }: { error: AppError }) {
  switch (error.type) {
    case 'not-found':
      return (
        <EmptyCard
          icon={<SearchX />}
          title="Page not found"
          description="This page doesn't exist or may have been moved."
          action={<Button href="/">Go home</Button>}
        />
      )
    case 'forbidden':
      return (
        <EmptyCard
          icon={<Lock />}
          title="Access restricted"
          description="You don't have permission to view this."
          action={<Button onClick={requestAccess}>Request access</Button>}
        />
      )
    case 'server-error':
      return (
        <EmptyCard
          icon={<AlertTriangle />}
          title="Something went wrong"
          description="Our servers encountered an error. We've been notified."
          action={<Button onClick={retry}>Try again</Button>}
        />
      )
    case 'network':
      return (
        <EmptyCard
          icon={<WifiOff />}
          title="Connection problem"
          description="Check your internet connection and try again."
          action={<Button onClick={retry}>Retry</Button>}
        />
      )
    case 'unauthorized':
      return (
        <EmptyCard
          icon={<UserX />}
          title="Sign in required"
          description="Sign in to access this content."
          action={<Button href="/login">Sign in</Button>}
        />
      )
  }
}
```

### Mapping HTTP status to error type

```ts
function classifyError(status: number | null): AppError {
  if (status === null) return { type: 'network' }
  if (status === 401)  return { type: 'unauthorized' }
  if (status === 403)  return { type: 'forbidden' }
  if (status === 404)  return { type: 'not-found' }
  if (status >= 500)   return { type: 'server-error' }
  return { type: 'server-error' } // catch-all
}
```

### Inline field errors vs page-level errors

```tsx
// Field-level: validation errors belong under the field
<Input name="email" />
{errors.email && <p className="text-red-500 text-sm mt-1">{errors.email}</p>}

// Page-level: API/network errors belong in an alert at the top of the form
{submitError && (
  <Alert variant="destructive">
    <AlertDescription>{submitError.message}</AlertDescription>
  </Alert>
)}
```

## Key Rules
- Never show raw HTTP status codes or stack traces to end users
- Retry only makes sense for 5xx and network errors — not 4xx
- 403 needs a path to get access (request, contact admin) — not just "go home"
- 404 should offer navigation back to a valid location
- 401 must redirect to login (or show sign-in prompt) — not just display an error
- Error states should match the visual weight of the surrounding UI (inline vs full-page vs toast)
- Log the full error server-side; show a sanitized version to the user
- Include a support reference ID for 5xx errors when possible (`Error ID: abc123`)
