# Pattern: Announcement Bar

## Overview
Announcement bars communicate time-sensitive information (sales, outages, new features) at the top of every page. The two correctness requirements are: (1) it must not re-appear after dismissal within a reasonable window, and (2) it must auto-expire after a set date so stale announcements don't linger. Both require the announcement to have a stable ID that doesn't change when copy is edited.

## Implementation

### Announcement data structure

```ts
interface Announcement {
  id: string          // Stable ID — never changes even if copy changes
  expiresAt: string   // ISO date — bar hidden after this
  variant: 'info' | 'warning' | 'success' | 'promo'
  message: string | React.ReactNode
  ctaLabel?: string
  ctaHref?: string
  dismissable?: boolean  // default true
}

// Only one announcement shown at a time — first non-expired, non-dismissed one wins
const ANNOUNCEMENTS: Announcement[] = [
  {
    id: 'summer-sale-2026',
    expiresAt: '2026-07-04',
    variant: 'promo',
    message: '🎉 Summer sale — 20% off all plans through July 4th',
    ctaLabel: 'Upgrade now',
    ctaHref: '/pricing',
  },
  {
    id: 'maintenance-june-2026',
    expiresAt: '2026-06-20',
    variant: 'warning',
    message: 'Scheduled maintenance on June 18 from 2–4 AM UTC. Brief downtime expected.',
  },
]
```

### AnnouncementBar component

```tsx
const STORAGE_KEY = 'dismissed_announcements'

function getActiveAnnouncement(): Announcement | null {
  const now = new Date()
  let dismissed: string[] = []

  try {
    dismissed = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '[]')
  } catch {}

  return ANNOUNCEMENTS.find((a) => {
    if (new Date(a.expiresAt) < now) return false   // Expired
    if (dismissed.includes(a.id)) return false       // Dismissed
    return true
  }) ?? null
}

function AnnouncementBar() {
  const [announcement, setAnnouncement] = useState<Announcement | null>(null)
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    const active = getActiveAnnouncement()
    if (active) {
      setAnnouncement(active)
      setVisible(true)
    }
  }, [])

  function dismiss() {
    if (!announcement) return
    setVisible(false)

    try {
      const dismissed = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '[]') as string[]
      if (!dismissed.includes(announcement.id)) {
        localStorage.setItem(STORAGE_KEY, JSON.stringify([...dismissed, announcement.id]))
      }
    } catch {}
  }

  if (!visible || !announcement) return null

  const variantStyles = {
    info:    'bg-blue-600 text-white',
    warning: 'bg-amber-500 text-white',
    success: 'bg-green-600 text-white',
    promo:   'bg-gradient-to-r from-purple-600 to-pink-600 text-white',
  }

  return (
    <div
      role="banner"
      aria-label="Announcement"
      className={`relative flex items-center justify-center px-4 py-2 text-sm
                  ${variantStyles[announcement.variant]}`}
    >
      <span>{announcement.message}</span>

      {announcement.ctaHref && announcement.ctaLabel && (
        <a
          href={announcement.ctaHref}
          className="ml-3 underline font-medium hover:no-underline"
        >
          {announcement.ctaLabel}
        </a>
      )}

      {(announcement.dismissable ?? true) && (
        <button
          onClick={dismiss}
          aria-label="Dismiss announcement"
          className="absolute right-3 opacity-80 hover:opacity-100"
        >
          <X size={16} />
        </button>
      )}
    </div>
  )
}
```

### Placement in layout

```tsx
// layout.tsx — bar goes above the navbar, not below
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        <AnnouncementBar />  {/* Above nav */}
        <Nav />
        <main>{children}</main>
      </body>
    </html>
  )
}
```

### Clearing old dismissed IDs

```ts
// Prune dismissed IDs for expired announcements on load
function pruneExpiredDismissals() {
  try {
    const dismissed = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '[]') as string[]
    const validIds = new Set(ANNOUNCEMENTS.map(a => a.id))
    const pruned = dismissed.filter(id => validIds.has(id))
    localStorage.setItem(STORAGE_KEY, JSON.stringify(pruned))
  } catch {}
}
```

## Key Rules
- Announcement ID must be stable — it's the key used to track dismissals. Never auto-generate from content
- Always set `expiresAt` — if you forget, the bar lives forever until someone manually removes it
- Place above the navigation, not below — it should be the very first thing on the page
- Show maximum one announcement at a time — stacking multiple bars is jarring
- `promo` variant should be visually distinct from `warning` — don't let sale banners look like alerts
- Don't show the bar again within the same session after dismissal (localStorage handles cross-session; sessionStorage handles same-session)
- Non-dismissable announcements (maintenance, legal) should use `dismissable: false`
- Mobile: keep copy short (one line max) — wrap gracefully, don't clip
