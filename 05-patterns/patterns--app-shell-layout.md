# Pattern: App Shell Layout

## Overview
A traditional SPA re-renders the entire page on navigation, including the chrome (navbar, sidebar, footer). An app shell keeps chrome rendered once — only the content area swaps. This feels instant because navigation never triggers chrome re-renders, skeleton states, or remounts. Without proper Suspense boundaries, a loading state in one content panel can block the entire page from rendering.

## Implementation

```tsx
// app/layout.tsx — the shell (never re-renders on navigation)
// In Next.js App Router, layout.tsx wraps all nested routes
// It mounts once per session, not on every navigation

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        {/* Shell renders immediately from cache */}
        {/* These components should have no async fetching */}
        {/* that would delay their rendering */}
        <AppShell>
          {/* children = route segments, swaps on navigation */}
          {/* Shell stays, only this area changes */}
          {children}
        </AppShell>
      </body>
    </html>
  )
}
```

```tsx
// AppShell.tsx — static chrome with content placeholder
// Shell components must be fast: no blocking data fetches
// Use client-side auth state for conditional nav items (not server fetches)

export function AppShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="app-shell">
      {/* Topbar: renders from local state/cache only */}
      <TopBar />

      <div className="app-body">
        {/* Sidebar: reads open state from localStorage, not API */}
        <Sidebar />

        {/* Content area: this is the ONLY thing that changes on navigation */}
        <main
          id="main-content"
          className="app-content"
          // Skip-to-main link target for keyboard users
        >
          {/*
            Suspense boundary ONLY around content, not the shell.
            Loading state appears inside main, not over the entire page.
            Shell stays visible during loading — this is the key benefit.
          */}
          <Suspense fallback={<ContentSkeleton />}>
            {children}
          </Suspense>
        </main>
      </div>
    </div>
  )
}
```

```css
/* App shell layout */
.app-shell {
  display: flex;
  flex-direction: column;
  height: 100vh;
  overflow: hidden;
}

.app-body {
  display: flex;
  flex: 1;
  overflow: hidden;
}

.app-content {
  flex: 1;
  overflow-y: auto;
  /* Content scrolls independently of sidebar */
  /* Sidebar does not scroll with content */
}
```

```tsx
// Content loading skeleton — shown only in the content area
// Shell (nav, sidebar) remains visible and stable
function ContentSkeleton() {
  return (
    <div aria-label="Loading page content" aria-live="polite">
      <div style={{ height: 40, background: '#f0f0f0', marginBottom: 16, borderRadius: 4 }} />
      <div style={{ height: 200, background: '#f0f0f0', borderRadius: 4 }} />
    </div>
  )
}
```

```tsx
// Route-level Suspense — each page segment wraps its data in Suspense
// app/dashboard/page.tsx
import { Suspense } from 'react'

export default function DashboardPage() {
  return (
    <div>
      <h1>Dashboard</h1>

      {/* Each data-dependent section has its own boundary */}
      {/* They load independently — one doesn't block the others */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
        <Suspense fallback={<CardSkeleton />}>
          <RevenueCard />    {/* async data */}
        </Suspense>

        <Suspense fallback={<CardSkeleton />}>
          <UsersCard />      {/* async data */}
        </Suspense>
      </div>

      <Suspense fallback={<TableSkeleton />}>
        <RecentOrdersTable />  {/* async data — loads independently */}
      </Suspense>
    </div>
  )
}
```

```tsx
// TopBar.tsx — shell component: no blocking async
// ✓ Reads auth from context (already fetched at root)
// ✓ Uses client state for notifications count
// ✗ Never fetch data here that would delay shell render

export function TopBar() {
  const { user } = useAuth()  // from context, not a new fetch

  return (
    <header className="topbar">
      <a href="/">
        <Logo />
      </a>

      {/* Notification count from SWR/React Query with stale-while-revalidate */}
      {/* Shows stale count immediately, updates in background */}
      <NotificationBell />

      <UserAvatar user={user} />
    </header>
  )
}
```

```tsx
// Navigation between routes — shell stays mounted
// ✓ Next.js Link component: shell persists, content swaps
<Link href="/settings">Settings</Link>

// ✓ router.push: same shell-persisting behavior
router.push('/dashboard')

// ✗ window.location.href: full page reload, shell remounts
// Don't use unless you actually need a full reload (rare)
```

## Key Rules
- Shell components (TopBar, Sidebar) must never contain blocking async operations — they must render from cache or local state.
- Put the Suspense boundary inside the shell's content area, not around the shell — the shell must stay visible during content loading.
- Navigation swaps the content area (`children`) — the shell (`layout.tsx`) stays mounted and does not re-render.
- Each data-dependent section in a page gets its own Suspense boundary — independent loading, independent skeletons.
- Shell state (sidebar open, theme, user info) comes from context providers mounted above the shell, not from fetches within shell components.
- Use `overflow: hidden` on the shell and `overflow-y: auto` on the content area — content scrolls independently of the fixed chrome.
- Include a "skip to main content" link that points to `#main-content` for keyboard accessibility.
- Avoid `window.location.href` for in-app navigation — it remounts the shell. Use `<Link>` or `router.push`.
- The shell's layout height is `100vh` with the content area taking remaining space via `flex: 1` — this prevents the page from growing taller than the viewport.
