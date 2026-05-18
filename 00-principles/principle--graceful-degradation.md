# Principle: Graceful Degradation

## The Problem

Features depend on external services, network connectivity, and browser APIs that may be unavailable. A site that crashes when one non-critical service is down is fragile. A site that silently continues without the failed feature is resilient.

## The Principle

Identify which features are core to the page's purpose and which are enhancements. When an enhancement fails, the page continues to work. When a core feature fails, show a clear error state rather than a blank or broken page.

## Feature Tiers

```
Tier 1 — Core (page must work):
  Content must render
  Primary actions must be completable

Tier 2 — Important (degrades to simpler version):
  Real-time updates → fall back to manual refresh
  Rich text editor → fall back to plain textarea
  Payment processing → show error + contact info

Tier 3 — Enhancement (silently removed):
  Analytics tracking → fail silently
  Social share buttons → hide on error
  Avatar images → show initials fallback
  Chat widget → hide if script fails to load
```

## Code Pattern: Try Enhancement, Fall Back Gracefully

```tsx
// Real-time subscription with offline fallback
function InvoiceList({ userId }: { userId: string }) {
  const { data: invoices, refetch } = useQuery({
    queryKey: ['invoices', userId],
    queryFn: () => getInvoicesByUser(userId),
  })

  // Try to subscribe to real-time; fail silently if not available
  const [isRealTime, setIsRealTime] = useState(false)

  useEffect(() => {
    let channel: RealtimeChannel | null = null

    try {
      channel = supabase
        .channel(`invoices-${userId}`)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'invoices', filter: `user_id=eq.${userId}` },
          () => { refetch() }
        )
        .subscribe((status) => {
          setIsRealTime(status === 'SUBSCRIBED')
        })
    } catch {
      // Real-time unavailable — user will need to refresh manually
      setIsRealTime(false)
    }

    return () => { if (channel) supabase.removeChannel(channel) }
  }, [userId])

  return (
    <div>
      {!isRealTime && (
        <div className="flex items-center gap-2 text-sm text-muted-foreground mb-4">
          <WifiOff className="h-4 w-4" />
          Live updates unavailable
          <button onClick={() => refetch()} className="underline">Refresh</button>
        </div>
      )}
      <InvoiceTable invoices={invoices ?? []} />
    </div>
  )
}
```

## Analytics Degradation

Analytics must never break the page:

```ts
// BAD: unhandled exception crashes the page
window.analytics.track('Invoice Viewed', { invoiceId })

// GOOD: wrapped in try/catch, fail silently
function track(event: string, properties?: Record<string, unknown>) {
  try {
    window.analytics?.track(event, properties)
  } catch {
    // Analytics failure is never the user's problem
  }
}
```

## Image Loading Degradation

```tsx
// Show initials when avatar fails to load
function Avatar({ user }: { user: { name: string; avatar_url?: string | null } }) {
  const [imgError, setImgError] = useState(false)

  if (!user.avatar_url || imgError) {
    return (
      <div className="flex h-10 w-10 items-center justify-center rounded-full bg-muted">
        <span className="text-sm font-medium text-muted-foreground">
          {user.name.slice(0, 2).toUpperCase()}
        </span>
      </div>
    )
  }

  return (
    <img
      src={user.avatar_url}
      alt={user.name}
      className="h-10 w-10 rounded-full object-cover"
      onError={() => setImgError(true)}
    />
  )
}
```

## Service Unavailability

For third-party integrations (email, SMS, payments):

```ts
async function sendInvoiceEmail(invoiceId: string): Promise<void> {
  try {
    await resend.emails.send({ ... })
    await markEmailSent(invoiceId)
  } catch (err) {
    // Email failed — but don't fail the whole invoice creation
    // Log for retry, notify admin
    console.error('Email send failed for invoice', invoiceId, err)
    await logFailedEmail(invoiceId, err instanceof Error ? err.message : 'Unknown error')
    // Don't re-throw — the primary action (invoice creation) succeeded
  }
}
```

The invoice was created successfully. The email failure is a separate concern, handled asynchronously.

## Client-Only Feature Detection

For browser APIs that may not be available:

```ts
const canShare = typeof window !== 'undefined' && typeof navigator.share === 'function'
const canClipboard = typeof navigator !== 'undefined' && !!navigator.clipboard
const canGeolocation = typeof navigator !== 'undefined' && !!navigator.geolocation
```

Never call these APIs without checking first — they throw on unsupported platforms.

## Error Boundaries as Degradation Boundaries

React ErrorBoundaries isolate failures to a section of the UI:

```tsx
// Wrap non-critical sections so their failure doesn't crash the page
<ErrorBoundary fallback={<div className="text-sm text-muted-foreground">Unavailable</div>}>
  <RecentActivityFeed />
</ErrorBoundary>
```

If `RecentActivityFeed` throws, only that section shows a fallback. The rest of the page continues.
