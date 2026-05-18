# Pattern: Announcement Banner

## Overview

Dismissible banner at the top of the page for promotions, feature announcements, system notices, or scheduled maintenance. Must persist dismissal in localStorage (so it doesn't reappear on refresh), support multiple simultaneous banners, and avoid layout shift during SSR hydration.

## Component

```tsx
interface Banner {
  id: string
  message: React.ReactNode
  variant?: 'info' | 'warning' | 'success' | 'error'
  cta?: { label: string; href: string }
  dismissible?: boolean
  expiresAt?: string  // ISO date — auto-hide after this date
}

const STORAGE_KEY = 'dismissed-banners'

function getDismissed(): Set<string> {
  if (typeof window === 'undefined') return new Set()
  try {
    const stored = localStorage.getItem(STORAGE_KEY)
    return new Set(stored ? JSON.parse(stored) : [])
  } catch {
    return new Set()
  }
}

function persistDismissal(id: string) {
  const dismissed = getDismissed()
  dismissed.add(id)
  localStorage.setItem(STORAGE_KEY, JSON.stringify([...dismissed]))
}

export function AnnouncementBanner({ banners }: { banners: Banner[] }) {
  const [dismissed, setDismissed] = useState<Set<string>>(new Set())
  const [mounted, setMounted] = useState(false)

  // Read localStorage only after mount to avoid SSR mismatch
  useEffect(() => {
    setDismissed(getDismissed())
    setMounted(true)
  }, [])

  const dismiss = (id: string) => {
    persistDismissal(id)
    setDismissed(prev => new Set([...prev, id]))
  }

  // Don't render anything on server to prevent hydration mismatch
  if (!mounted) return null

  const visible = banners.filter(b => {
    if (dismissed.has(b.id)) return false
    if (b.expiresAt && new Date(b.expiresAt) < new Date()) return false
    return true
  })

  if (visible.length === 0) return null

  return (
    <div className="space-y-px">
      {visible.map(banner => (
        <BannerItem key={banner.id} banner={banner} onDismiss={() => dismiss(banner.id)} />
      ))}
    </div>
  )
}

function BannerItem({ banner, onDismiss }: { banner: Banner; onDismiss: () => void }) {
  const bgColors = {
    info:    'bg-blue-600 text-white',
    warning: 'bg-amber-500 text-white',
    success: 'bg-green-600 text-white',
    error:   'bg-red-600 text-white',
  }

  return (
    <div
      role="banner"
      className={cn(
        'flex items-center justify-center gap-4 px-4 py-2 text-sm',
        bgColors[banner.variant ?? 'info']
      )}
    >
      <p className="flex-1 text-center">{banner.message}</p>

      {banner.cta && (
        <a
          href={banner.cta.href}
          className="underline font-semibold whitespace-nowrap hover:no-underline"
        >
          {banner.cta.label}
        </a>
      )}

      {banner.dismissible !== false && (
        <button
          onClick={onDismiss}
          aria-label="Dismiss banner"
          className="flex-shrink-0 opacity-80 hover:opacity-100 ml-2"
        >
          ×
        </button>
      )}
    </div>
  )
}
```

## Usage

```tsx
const BANNERS: Banner[] = [
  {
    id: 'summer-sale-2024',     // Change ID to re-show after dismissal
    message: '🎉 Summer Sale — 30% off all plans through August 31',
    cta: { label: 'Upgrade now', href: '/pricing' },
    expiresAt: '2024-09-01T00:00:00Z',
  },
  {
    id: 'maintenance-2024-08-15',
    variant: 'warning',
    message: 'Scheduled maintenance on Aug 15, 2AM–4AM UTC',
    dismissible: false,         // Cannot be dismissed — it's critical info
    expiresAt: '2024-08-15T04:00:00Z',
  },
]

// In app layout
export default function Layout({ children }) {
  return (
    <>
      <AnnouncementBanner banners={BANNERS} />
      <main>{children}</main>
    </>
  )
}
```

## Server-Side Banner Data

For banners managed via CMS or feature flags:

```tsx
// app/layout.tsx (React Server Component)
async function Layout({ children }) {
  const banners = await fetchActiveBanners()  // from DB or CMS
  return (
    <>
      <AnnouncementBanner banners={banners} />
      {children}
    </>
  )
}
```

Cache aggressively — banner data changes rarely:

```ts
const banners = await fetch('/api/banners', {
  next: { revalidate: 300 }  // 5 min cache
})
```

## Key Rules

- Use `useEffect` to read localStorage — never during render — to prevent SSR hydration mismatch.
- Change the `id` to force the banner to re-appear for users who previously dismissed it (e.g., `sale-v2` vs `sale-v1`).
- `expiresAt` prevents stale banners from showing after their event has passed — always set it.
- `role="banner"` is already used by the `<header>` element — prefer `role="alert"` for urgent messages.
- Non-dismissible banners should be reserved for genuinely critical info (downtime, legal requirements).
