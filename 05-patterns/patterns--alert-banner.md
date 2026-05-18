# Pattern: Alert Banner

## Overview

Alert banners communicate system status: maintenance windows, outages, feature announcements, degraded performance. They differ from toasts (transient, triggered by user actions) — banners persist until dismissed or the condition clears. The key requirements: accessible role, clear severity levels, dismissibility, and not flashing on every page load after dismissal.

## Component

```tsx
type AlertVariant = 'info' | 'success' | 'warning' | 'error'

interface AlertBannerProps {
  id: string             // Unique ID for localStorage dismissal tracking
  variant: AlertVariant
  message: string
  action?: { label: string; href?: string; onClick?: () => void }
  dismissible?: boolean
  expiresAt?: Date      // Auto-hide after this date
}

const VARIANT_STYLES: Record<AlertVariant, { bg: string; text: string; icon: string }> = {
  info:    { bg: 'bg-blue-50 border-blue-200',   text: 'text-blue-800',  icon: 'ℹ' },
  success: { bg: 'bg-green-50 border-green-200', text: 'text-green-800', icon: '✓' },
  warning: { bg: 'bg-amber-50 border-amber-200', text: 'text-amber-800', icon: '⚠' },
  error:   { bg: 'bg-red-50 border-red-200',     text: 'text-red-800',   icon: '✕' },
}

export function AlertBanner({ id, variant, message, action, dismissible = true, expiresAt }: AlertBannerProps) {
  const [visible, setVisible] = useState(false)  // Start hidden (SSR safe)

  useEffect(() => {
    // Check expiry
    if (expiresAt && new Date() > expiresAt) return

    // Check if dismissed
    const dismissed = localStorage.getItem(`alert-dismissed:${id}`)
    if (!dismissed) setVisible(true)
  }, [id, expiresAt])

  function dismiss() {
    localStorage.setItem(`alert-dismissed:${id}`, '1')
    setVisible(false)
  }

  if (!visible) return null

  const styles = VARIANT_STYLES[variant]
  const ariaRole = variant === 'error' || variant === 'warning' ? 'alert' : 'status'

  return (
    <div
      role={ariaRole}
      aria-live={ariaRole === 'alert' ? 'assertive' : 'polite'}
      className={`flex items-center gap-3 px-4 py-3 border-b ${styles.bg} ${styles.text}`}
    >
      <span aria-hidden="true">{styles.icon}</span>
      <p className="flex-1 text-sm">{message}</p>
      {action && (
        action.href
          ? <a href={action.href} className="text-sm font-medium underline">{action.label}</a>
          : <button onClick={action.onClick} className="text-sm font-medium underline">{action.label}</button>
      )}
      {dismissible && (
        <button
          onClick={dismiss}
          aria-label="Dismiss alert"
          className="ml-auto p-1 rounded hover:bg-black/10"
        >
          ×
        </button>
      )}
    </div>
  )
}
```

## CMS-Driven System Banner

```tsx
// Fetched from CMS/config — enables non-developer updates
interface SystemBanner {
  id: string
  variant: AlertVariant
  message: string
  active: boolean
  expiresAt: string | null
}

async function getActiveBanner(): Promise<SystemBanner | null> {
  const banners = await db.select()
    .from(systemBanners)
    .where(
      and(
        eq(systemBanners.active, true),
        or(isNull(systemBanners.expiresAt), gt(systemBanners.expiresAt, new Date())),
      )
    )
    .orderBy(desc(systemBanners.createdAt))
    .limit(1)

  return banners[0] ?? null
}
```

```tsx
// In layout.tsx
export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const banner = await getActiveBanner()

  return (
    <html>
      <body>
        {banner && (
          <AlertBanner
            id={banner.id}
            variant={banner.variant}
            message={banner.message}
            expiresAt={banner.expiresAt ? new Date(banner.expiresAt) : undefined}
          />
        )}
        {children}
      </body>
    </html>
  )
}
```

## Maintenance Mode Banner

```tsx
function MaintenanceBanner() {
  const scheduled = new Date('2026-06-01T02:00:00Z')
  const now = new Date()
  const hoursUntil = Math.round((scheduled.getTime() - now.getTime()) / (1000 * 60 * 60))

  if (hoursUntil > 24) return null  // Only show within 24 hours

  return (
    <AlertBanner
      id={`maintenance-${scheduled.toISOString()}`}
      variant="warning"
      message={`Scheduled maintenance on ${scheduled.toLocaleDateString()} from 2–4am UTC. The app will be unavailable for ~30 minutes.`}
      dismissible={false}  // Too important to dismiss
    />
  )
}
```

## Key Rules

- `useEffect` for dismissal state check prevents SSR/client mismatch — localStorage is not available during server rendering, so always initialize as hidden.
- Change the `id` when the banner content changes significantly — it re-shows for users who dismissed the old version.
- `role="alert"` with `aria-live="assertive"` for errors/warnings (interrupts screen reader), `role="status"` with `aria-live="polite"` for info/success (waits for current speech to finish).
- Non-dismissible banners should be used sparingly and only for urgent, time-sensitive info (active outage, maintenance window).
- The `expiresAt` check in `useEffect` ensures the banner auto-disappears after its relevance window, even if the user hasn't dismissed it.
