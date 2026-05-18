# Fail Gracefully

## What It Means

When a dependency fails (external API, database, third-party service), the application should:
1. Continue working at reduced functionality when possible
2. Show a clear error state when not possible
3. Never show a blank page or cryptic error to the user
4. Never crash silently and appear to succeed

## Degradation Tiers

Define what your app can do without each dependency:

| Dependency fails | Degrade to |
|---|---|
| Search service | Show all items unfiltered |
| Analytics (GA, PostHog) | Continue — analytics is never critical |
| CDN (images fail) | Show alt text, layout holds |
| AI feature | Disable the AI button, show manual alternative |
| Email notifications | Queue for retry, don't fail the primary action |
| Audit logging | Log error, continue — audit is non-critical |

## Error Boundaries (React)

```typescript
// components/ErrorBoundary.tsx
'use client'
import { Component, type ReactNode } from 'react'

interface Props {
  children: ReactNode
  fallback?: ReactNode
}

interface State {
  error: Error | null
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null }
  
  static getDerivedStateFromError(error: Error): State {
    return { error }
  }
  
  componentDidCatch(error: Error, info: { componentStack: string }) {
    console.error('ErrorBoundary caught:', error, info.componentStack)
    // Report to error monitoring (Sentry, etc.)
  }
  
  render() {
    if (this.state.error) {
      return this.props.fallback ?? (
        <div className="p-4 border border-destructive/50 rounded-md bg-destructive/10">
          <p className="text-sm text-destructive">Something went wrong loading this section.</p>
          <button
            onClick={() => this.setState({ error: null })}
            className="text-xs text-muted-foreground underline mt-1"
          >
            Try again
          </button>
        </div>
      )
    }
    return this.props.children
  }
}

// Usage — wrap sections independently so one failure doesn't kill the page:
<ErrorBoundary fallback={<ChartError />}>
  <RevenueChart data={data} />
</ErrorBoundary>
```

## Graceful Fetch Errors

```typescript
async function fetchWithFallback<T>(
  fetcher: () => Promise<T>,
  fallback: T
): Promise<T> {
  try {
    return await fetcher()
  } catch (error) {
    console.error('Fetch failed, using fallback:', error)
    return fallback
  }
}

// Usage:
const stats = await fetchWithFallback(
  () => analyticsService.getStats(),
  { pageViews: 0, visitors: 0 }  // empty stats — dashboard still renders
)
```

## Server Action Resilience

```typescript
export async function createInvoice(data: CreateInvoiceData) {
  // Primary operation — must succeed:
  const { data: invoice, error } = await supabase.from('invoices').insert(data).select().single()
  if (error) return { success: false, error: 'Failed to create invoice' }
  
  // Secondary operation — can fail without failing the primary:
  try {
    await sendInvoiceEmail(invoice)
  } catch (emailError) {
    console.error('Email failed for invoice', invoice.id, emailError)
    // Queue for retry — don't return error to user
  }
  
  // Tertiary (analytics/audit) — never block:
  logAudit({ action: 'create', resourceType: 'invoice', resourceId: invoice.id })
    .catch(e => console.error('Audit log failed:', e))  // fire and forget
  
  return { success: true, data: invoice }
}
```

## Empty State vs Error State

These are different — don't conflate them:

```typescript
function InvoiceList() {
  const { data, error, isLoading } = useInvoices()
  
  if (isLoading) return <InvoiceListSkeleton />
  
  if (error) return (
    <Alert variant="destructive">
      <AlertTitle>Couldn't load invoices</AlertTitle>
      <AlertDescription>
        Check your connection and{' '}
        <button onClick={() => refetch()} className="underline">try again</button>
      </AlertDescription>
    </Alert>
  )
  
  if (data.length === 0) return (
    <EmptyState
      title="No invoices yet"
      description="Create your first invoice to get started"
      action={<Button onClick={() => router.push('/invoices/new')}>Create invoice</Button>}
    />
  )
  
  return <InvoiceTable invoices={data} />
}
```

An error state offers retry. An empty state offers a creation action. Never show a blank white space.

## Never Swallow Errors Silently

```typescript
// WRONG — error disappears:
try {
  await riskyOperation()
} catch (e) {
  // nothing here
}

// CORRECT — at minimum, log:
try {
  await riskyOperation()
} catch (e) {
  console.error('riskyOperation failed:', e)
  // then decide: throw, return error, or degrade gracefully
}
```

Swallowing errors is the root cause of "works on my machine" bugs — the failure exists but leaves no trace.
