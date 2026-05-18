# Failure: Missing Error Handling

## Overview

Missing error handling silently swallows exceptions, produces cryptic errors for users, or crashes the server. The most dangerous form: `try/catch` blocks that do nothing, `async` functions without await error propagation, and fetch calls that treat all non-200 responses as success.

## Common Missing Error Handling Patterns

### 1. Fetch Without Response Check

```ts
// BAD — doesn't check if response is ok
const data = await fetch('/api/users').then(r => r.json())

// GOOD — check status before parsing
async function apiFetch<T>(url: string, options?: RequestInit): Promise<T> {
  const res = await fetch(url, options)
  if (!res.ok) {
    const errorText = await res.text().catch(() => 'Unknown error')
    throw new Error(`HTTP ${res.status}: ${errorText}`)
  }
  return res.json()
}
```

A 404 or 500 response still resolves `fetch` — the promise only rejects on network failures.

### 2. Empty Catch Blocks

```ts
// BAD — error silently disappears
try {
  await sendEmail(user.email)
} catch {}

// BAD — logs but doesn't handle
try {
  await sendEmail(user.email)
} catch (e) {
  console.error(e)  // Logged but caller doesn't know it failed
}

// GOOD — decide: retry, fallback, or rethrow
try {
  await sendEmail(user.email)
} catch (e) {
  // Option 1: Rethrow to let the caller handle
  throw new EmailError(`Failed to send to ${user.email}`, { cause: e })

  // Option 2: Fallback — mark for retry later
  await db.insert(emailRetryQueue).values({ userId: user.id, template: 'welcome' })

  // Option 3: Non-critical — log and continue
  logger.warn({ err: e, userId: user.id }, 'welcome email failed — non-blocking')
}
```

### 3. Unhandled Promise Rejections

```ts
// BAD — fire and forget without error handling
sendWelcomeEmail(user.email)  // If this throws, it's an unhandled rejection

// GOOD — handle explicitly
sendWelcomeEmail(user.email).catch(err =>
  logger.error({ err, userId: user.id }, 'welcome email failed')
)

// Or await it if the caller should know
await sendWelcomeEmail(user.email)
```

### 4. Missing Async Error Propagation in Express/Next.js

```ts
// BAD — async errors crash the handler without a response
app.get('/users/:id', async (req, res) => {
  const user = await db.getUser(req.params.id)  // If this throws, no error is caught
  res.json(user)
})

// GOOD — wrap async route handlers
function asyncHandler(fn: RequestHandler): RequestHandler {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next)
}

app.get('/users/:id', asyncHandler(async (req, res) => {
  const user = await db.getUser(req.params.id)
  res.json(user)
}))
```

In Next.js App Router, unhandled errors in Route Handlers return a 500 automatically, but the error isn't logged.

## Error Boundary Pattern (React)

```tsx
// Without an error boundary, a render error crashes the entire app
class ErrorBoundary extends React.Component<
  { children: ReactNode; fallback: ReactNode },
  { hasError: boolean }
> {
  state = { hasError: false }

  static getDerivedStateFromError() {
    return { hasError: true }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    logger.error({ error, componentStack: info.componentStack }, 'render error')
  }

  render() {
    if (this.state.hasError) return this.props.fallback
    return this.props.children
  }
}

// Usage — wrap sections that might fail independently
<ErrorBoundary fallback={<div>Failed to load chart</div>}>
  <RevenueChart />
</ErrorBoundary>
```

## Error Response Format

```ts
// Consistent error format across all API routes
interface ApiError {
  error: string
  code?: string
  details?: unknown
}

function errorResponse(message: string, status: number, code?: string): Response {
  const body: ApiError = { error: message, ...(code && { code }) }
  return Response.json(body, { status })
}

// Usage
if (!user) return errorResponse('User not found', 404, 'USER_NOT_FOUND')
if (!authorized) return errorResponse('Forbidden', 403, 'INSUFFICIENT_PERMISSIONS')
```

## Error Logging

```ts
// Always log errors with enough context to debug
try {
  await processOrder(orderId)
} catch (e) {
  logger.error({
    err: e,
    orderId,
    userId,
    action: 'processOrder',
  }, 'Order processing failed')
  throw e  // Re-throw after logging
}
```

## Key Rules

- Every `fetch` call must check `res.ok` before calling `.json()` — a 4xx/5xx response is not a network error.
- Empty `catch` blocks are almost always wrong — decide to retry, fallback, log+continue, or rethrow.
- Unhandled promise rejections in Node.js emit `unhandledRejection` events and may crash the process — always handle or propagate.
- Use error boundaries in React to isolate widget failures from crashing the full page.
- Log errors with structured context (action, IDs) not just message strings — you'll need the context to debug production failures.
