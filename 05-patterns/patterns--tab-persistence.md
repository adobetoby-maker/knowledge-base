# Pattern: Tab State Persistence

## Overview
Tabs that reset on page reload or navigation break user context — they were on "Settings > Notifications" and after saving are dumped back on the default tab. URL-based tab state enables deep linking, browser back/forward support, and sharing specific tabs. Query params are superior to hash-based approaches for SSR because they're readable on the server.

## Implementation

```typescript
// lib/tabs.ts — shared tab utilities
export type TabValue = string

export function getTabFromParams(
  params: URLSearchParams | Record<string, string | string[] | undefined>,
  paramName = 'tab',
  validValues: readonly string[],
  fallback: string
): string {
  const raw = params instanceof URLSearchParams
    ? params.get(paramName)
    : params[paramName]

  const value = Array.isArray(raw) ? raw[0] : raw

  // Validate against allowed values — invalid URL params fall back gracefully
  if (value && validValues.includes(value)) return value
  return fallback
}
```

```tsx
// tabs-with-url.tsx — Next.js App Router implementation
'use client'

import { useRouter, useSearchParams, usePathname } from 'next/navigation'
import { useCallback } from 'react'

const TABS = ['overview', 'settings', 'billing', 'team'] as const
type TabId = typeof TABS[number]

export function SettingsTabs() {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()

  // Read active tab from URL — with fallback to first tab
  const activeTab = getTabFromParams(searchParams, 'tab', TABS, TABS[0]) as TabId

  const setTab = useCallback((tab: TabId) => {
    // Preserve other existing query params (pagination, filters, etc.)
    const params = new URLSearchParams(searchParams.toString())
    params.set('tab', tab)

    // pushState preserves browser history — back button returns to previous tab
    // Use replace when tab change shouldn't be a history entry (e.g., sub-tabs)
    router.push(`${pathname}?${params.toString()}`, { scroll: false })
  }, [router, pathname, searchParams])

  return (
    <div>
      {/* Tab navigation */}
      <div role="tablist" aria-label="Settings sections">
        {TABS.map(tab => (
          <button
            key={tab}
            role="tab"
            id={`tab-${tab}`}
            aria-selected={activeTab === tab}
            aria-controls={`panel-${tab}`}
            onClick={() => setTab(tab)}
            style={{
              fontWeight: activeTab === tab ? 700 : 400,
              borderBottom: activeTab === tab ? '2px solid currentColor' : '2px solid transparent',
            }}
          >
            {tab.charAt(0).toUpperCase() + tab.slice(1)}
          </button>
        ))}
      </div>

      {/* Tab panels — only active panel is shown */}
      {TABS.map(tab => (
        <div
          key={tab}
          role="tabpanel"
          id={`panel-${tab}`}
          aria-labelledby={`tab-${tab}`}
          hidden={activeTab !== tab}
          // hidden attribute removes from accessibility tree when inactive
          // CSS display:none alternative loses ARIA semantics
          tabIndex={0}
        >
          <TabContent tab={tab} />
        </div>
      ))}
    </div>
  )
}
```

```tsx
// Server Component version — reads tab at render time
// app/settings/page.tsx
export default function SettingsPage({
  searchParams,
}: {
  searchParams: { tab?: string }
}) {
  // SSR reads the query param directly — no hydration needed
  const activeTab = getTabFromParams(searchParams, 'tab', TABS, 'overview') as TabId

  return (
    <div>
      {/* Pass activeTab to client component for interactive behavior */}
      <TabNav activeTab={activeTab} />

      {/* Server-render the active panel content directly */}
      <Suspense fallback={<TabSkeleton />}>
        {activeTab === 'overview'  && <OverviewTab />}
        {activeTab === 'settings'  && <SettingsTab />}
        {activeTab === 'billing'   && <BillingTab />}
        {activeTab === 'team'      && <TeamTab />}
      </Suspense>
    </div>
  )
}
```

```tsx
// Hash-based alternative — when SSR access to tab is not needed
// Simpler but the server can't know which tab to render
// Use query params (?tab=x) instead unless you have a reason for hash

// ❌ Hash-based: not available in server components, not SSR-friendly
function HashTabs() {
  const [tab, setTab] = useState(() => {
    // Hash is only available in browser
    return window.location.hash.slice(1) || 'overview'
  })

  // Can't read this on server, so SSR sends wrong initial content
  return <Tabs activeTab={tab} />
}

// ✓ Query param: available in Server Components
// ?tab=settings is the correct approach for SSR
```

```typescript
// Deep linking — users can bookmark or share a direct link to a tab
// https://app.example.com/settings?tab=billing

// When building links to tabs in other parts of the app:
function BillingLink() {
  return <a href="/settings?tab=billing">Manage billing</a>
}
```

## Key Rules
- Use query params (`?tab=settings`) for tab state — hash (`#settings`) is unavailable in server components and breaks SSR.
- Use `router.push` (not `replace`) so browser back/forward moves between tabs.
- Read the tab value on the server side and render the correct panel — don't wait for client hydration.
- Validate the URL param against a list of known tab IDs and fall back to the default — never trust raw URL input.
- Preserve other query params when setting the tab: use `new URLSearchParams(current.toString()).set(...)` not a fresh object.
- Use `role="tab"` with `aria-selected` on buttons and `role="tabpanel"` with `aria-labelledby` on panels.
- Use the `hidden` attribute on inactive panels — it removes them from the accessibility tree, which `display: none` via CSS does not always guarantee.
- Building cross-page links to a tab? Use `?tab=billing` in the `href` directly.
- Pass `scroll: false` to `router.push` — switching tabs should not scroll the page to the top.
