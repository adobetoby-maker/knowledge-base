# Pattern: Announcement / Feature Toast

## Overview

Feature announcement toasts ("We've added dark mode!") differ from transactional toasts ("File saved") in timing, frequency, and intent. They should appear after the user has engaged with the page (not immediately on load), show only once per user, have a primary CTA alongside dismiss, and be positioned to minimize disruption. Getting "show once" wrong is the most common failure — forgetting to check localStorage means the same announcement badgers users on every visit.

## Show-Once Logic

```ts
const ANNOUNCEMENT_KEY = 'feature_dark_mode_v1'

export function hasSeenAnnouncement(key: string): boolean {
  try {
    return localStorage.getItem(key) === 'seen'
  } catch {
    return true  // if localStorage unavailable, don't show
  }
}

export function markAnnouncementSeen(key: string): void {
  try {
    localStorage.setItem(key, 'seen')
  } catch {
    // silently fail — don't block UX over localStorage errors
  }
}
```

**Why a versioned key like `_v1`:** When you ship a new version of a feature, bump the key to re-show the announcement to users who already dismissed the old one. Without versioning, users who saw "dark mode beta" will never see "dark mode is now stable."

## Delayed Show Implementation

```tsx
import { useState, useEffect } from 'react'

const DELAY_MS = 3000  // 3 seconds after page load
const KEY = 'feature_dark_mode_v1'

export function FeatureAnnouncement() {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    if (hasSeenAnnouncement(KEY)) return

    const timer = setTimeout(() => setVisible(true), DELAY_MS)
    return () => clearTimeout(timer)
  }, [])

  function handleCTA() {
    markAnnouncementSeen(KEY)
    setVisible(false)
    // navigate to feature or open modal
    router.push('/settings?tab=appearance')
  }

  function handleDismiss() {
    markAnnouncementSeen(KEY)
    setVisible(false)
  }

  if (!visible) return null

  return (
    <AnnouncementToast
      title="Dark mode is here"
      description="Switch to dark mode in your settings."
      ctaLabel="Try it now"
      onCTA={handleCTA}
      onDismiss={handleDismiss}
    />
  )
}
```

**Why 3 seconds:** Immediate toasts fire before users orient to the page and get instantly dismissed without reading. 3 seconds is enough time for the page to settle visually and the user to begin their task, but not so long it feels like an interruption they forgot was coming.

## Toast Component

```tsx
import { useEffect } from 'react'
import { X } from 'lucide-react'

type AnnouncementToastProps = {
  title: string
  description: string
  ctaLabel: string
  onCTA: () => void
  onDismiss: () => void
  autoDismissMs?: number  // optional — announcements often benefit from staying
}

export function AnnouncementToast({
  title,
  description,
  ctaLabel,
  onCTA,
  onDismiss,
  autoDismissMs,
}: AnnouncementToastProps) {
  useEffect(() => {
    if (!autoDismissMs) return
    const timer = setTimeout(onDismiss, autoDismissMs)
    return () => clearTimeout(timer)
  }, [autoDismissMs, onDismiss])

  return (
    <div
      role="status"
      aria-live="polite"
      aria-atomic="true"
      className="announcement-toast"
    >
      <div className="announcement-toast__body">
        <p className="announcement-toast__title">{title}</p>
        <p className="announcement-toast__desc">{description}</p>
      </div>
      <div className="announcement-toast__actions">
        <button
          onClick={onCTA}
          className="announcement-toast__cta"
        >
          {ctaLabel}
        </button>
        <button
          onClick={onDismiss}
          aria-label="Dismiss announcement"
          className="announcement-toast__dismiss"
        >
          <X size={16} aria-hidden />
        </button>
      </div>
    </div>
  )
}
```

## Positioning

Feature announcements work best at **bottom-right** for desktop (out of primary task area) or **bottom-center** for mobile (thumb-reachable). Top-center is acceptable for high-priority announcements (outages, critical changes) but feels aggressive for feature news.

```css
.announcement-toast {
  position: fixed;
  bottom: 1.5rem;
  right: 1.5rem;
  max-width: 360px;
  z-index: 50;

  /* Slide up from bottom */
  animation: slide-up 300ms ease-out;
}

@keyframes slide-up {
  from { transform: translateY(20px); opacity: 0; }
  to   { transform: translateY(0);    opacity: 1; }
}

@media (max-width: 640px) {
  .announcement-toast {
    bottom: 0;
    right: 0;
    left: 0;
    max-width: 100%;
    border-bottom-left-radius: 0;
    border-bottom-right-radius: 0;
  }
}

@media (prefers-reduced-motion: reduce) {
  .announcement-toast { animation: none; }
}
```

## Multi-Announcement Queue

If shipping multiple feature announcements, show them sequentially — never stack:

```ts
const QUEUE = ['feature_search_v2', 'feature_export_v1', 'feature_themes_v1']

export function nextPendingAnnouncement(): string | null {
  return QUEUE.find(key => !hasSeenAnnouncement(key)) ?? null
}
```

## Key Rules

- Check localStorage before showing — never show the same announcement twice
- Version the localStorage key (`_v1`) — allows re-announcing when the feature meaningfully updates
- Delay 3–5 seconds after page load — immediate toasts get dismissed reflexively without reading
- Always provide both a CTA and a dismiss button — never force users to take the CTA to close it
- `role="status"` + `aria-live="polite"` — screen readers announce it without interrupting current activity
- Auto-dismiss is optional for announcements — transactional toasts auto-dismiss; feature news can persist
- Show one announcement at a time — queue them, never stack
