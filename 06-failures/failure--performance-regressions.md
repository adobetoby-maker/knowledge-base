# Failure: Performance Regressions

## Problem: LCP Suddenly Worse After Deploying New Component

**Symptom**: Lighthouse LCP score dropped from 1.2s to 3.8s after adding a new hero section.

**Root cause**: New hero image is missing the `priority` prop, causing it to lazy-load instead of preload.

**Fix**: Every above-the-fold `<Image>` must have `priority={true}`:
```tsx
// BAD: hero image lazy-loads by default
<Image src="/hero.jpg" alt="Hero" fill />

// GOOD: priority preloads the image before render
<Image src="/hero.jpg" alt="Hero" fill priority />
```

Also check: hero image file size. WebP under 200KB loads quickly on mobile. If it's > 500KB, compress first.

## Problem: CLS (Layout Shift) After Hydration

**Symptom**: Page content jumps when React hydrates. CLS score is high.

**Root cause 1**: Images without explicit dimensions:
```tsx
// BAD: no dimensions → browser doesn't know size until image loads
<img src="/logo.png" alt="Logo" />

// GOOD: explicit dimensions prevent layout shift
<Image src="/logo.png" alt="Logo" width={120} height={40} />
```

**Root cause 2**: Fonts loading after content renders (FOUT — Flash of Unstyled Text):
```tsx
// next/font handles font optimization automatically
import { Inter } from 'next/font/google'
const inter = Inter({ subsets: ['latin'], display: 'swap' })
// display: 'swap' still allows FOUT — use 'optional' or 'block' for no-FOUT
```

**Root cause 3**: Conditional content that changes size between SSR and hydration:
```tsx
// BAD: shows different content server vs client → CLS
const isLoggedIn = typeof window !== 'undefined' && !!localStorage.getItem('user')
return isLoggedIn ? <UserNav /> : <GuestNav />

// GOOD: use a stable server-rendered default + hydrate gracefully
// Or reserve space with min-height so layout doesn't shift
<div className="min-h-10">
  <Suspense fallback={<div className="h-10" />}>
    <UserNav />
  </Suspense>
</div>
```

## Problem: Bundle Size Grew Unexpectedly

**Symptom**: Build output shows `+ 120 KB` in client bundle after adding a component.

**Root cause**: Heavy package imported in a Client Component where it could be Server-side only.

**Diagnosis**:
```bash
# Find what's in the bundle
cd /Users/drive/<project>
ANALYZE=true npm run build
# Opens bundle analyzer in browser
```

**Fix 1**: Move heavy computation to a Server Component:
```tsx
// Heavy crypto/parsing library → move to server
// app/page.tsx (Server Component — not in bundle)
import { heavyLib } from 'heavy-lib'
const processed = heavyLib.process(data)
return <ClientDisplay data={processed} />
```

**Fix 2**: Lazy-load heavy components:
```tsx
// Don't load until needed
const HeavyEditor = dynamic(() => import('./HeavyEditor'), { ssr: false })
```

## Problem: Every Page Transition Re-Fetches Same Data

**Symptom**: Network tab shows the same API call firing on every navigation.

**Root cause**: TanStack Query's `staleTime` defaults to 0 — data is immediately stale and refetches on every focus/remount.

**Fix**: Set appropriate `staleTime` for data that doesn't change frequently:
```ts
useQuery({
  queryKey: ['user-profile'],
  queryFn: getProfile,
  staleTime: 5 * 60 * 1000,  // 5 minutes — profile doesn't change per-navigation
})

// For frequently-changing data (invoice list):
useQuery({
  queryKey: ['invoices'],
  queryFn: getInvoices,
  staleTime: 30 * 1000,  // 30 seconds
})
```

## Problem: N+1 Queries Making Page Load Slow

**Symptom**: Supabase shows 100+ queries for a page that shows 20 items.

**Root cause**: Queries inside loops:
```ts
// BAD: 1 query per invoice → N+1
const invoices = await getInvoices()
const invoicesWithClients = await Promise.all(
  invoices.map(inv => supabase.from('clients').select('name').eq('id', inv.client_id).single())
)

// GOOD: join in a single query
const { data } = await supabase
  .from('invoices')
  .select('*, clients(name, email)')  // Embedded join
  .order('created_at', { ascending: false })
```

## Problem: Framer Motion Causing Frame Drops on Mobile

**Symptom**: Scroll animations stutter on mobile devices.

**Root cause 1**: Animating non-GPU-composited properties (`margin`, `padding`, `width`, `height`, `top`, `left`).

**Fix**: Only animate `transform` and `opacity`:
```tsx
// BAD: causes layout recalculation on every frame
<motion.div animate={{ top: 0, marginTop: 20 }} />

// GOOD: GPU-composited only
<motion.div animate={{ y: 0, opacity: 1 }} />
```

**Root cause 2**: Animating too many elements simultaneously. If 50+ elements are animating at once, the GPU is overwhelmed.

**Fix**: Stagger animations so fewer elements animate in parallel, or virtualize and only animate visible elements.
