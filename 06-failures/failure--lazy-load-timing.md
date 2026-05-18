# Failure: Race Conditions with Lazy-Loaded Components

## Why Lazy Loading Introduces Timing Bugs

`React.lazy` defers loading a component's bundle until it's first rendered. This is great for initial load performance but introduces timing: the component isn't available yet, something else depends on it being available, and a race condition forms. The bugs are invisible in fast networks (dev + fast WiFi) and only appear on slow connections or first load.

## Suspense Boundary Placement

Every `lazy` component must have a `Suspense` boundary somewhere in its ancestor tree. Without one, React throws an error when the lazy component suspends. With one placed too high, an entire page shows a loading spinner when only a small tab changes.

Place `Suspense` as close to the lazy component as possible:

```tsx
// Too coarse — entire layout spins on any lazy load
<Suspense fallback={<PageSpinner />}>
  <Layout>
    <TabContent />
  </Layout>
</Suspense>

// Correct — only the tab content suspends
<Layout>
  <Suspense fallback={<TabSkeleton />}>
    <TabContent />
  </Suspense>
</Layout>
```

Multiple independent `Suspense` boundaries allow unrelated parts of the UI to load independently. This is especially important in tab-based UIs — a tab that's loading shouldn't block the nav bar from being interactive.

## Layout Shift from Lazy Components

When a lazy component loads, it inserts into the DOM and pushes content around. The Cumulative Layout Shift (CLS) score suffers and users experience jarring jumps.

The fix is a skeleton/placeholder that reserves the same space the component will occupy:

```tsx
<Suspense fallback={<div style={{ height: '400px' }} className="skeleton" />}>
  <HeavyChart />
</Suspense>
```

The placeholder height should match the expected rendered height. If you don't know the exact height, use a min-height that's close — an imperfect placeholder is better than no placeholder.

## `prefetch` to Preload on Hover

Lazy loading defers the network request until the component renders. For predictable interactions (clicking a tab, hovering a nav link), you can start the fetch earlier:

```tsx
const HeavyTab = lazy(() => import('./HeavyTab'));

// Preload on hover before the user clicks
function handleMouseEnter() {
  import('./HeavyTab'); // fires the fetch, result is cached
}

<button onMouseEnter={handleMouseEnter} onClick={navigateToTab}>
  Heavy Tab
</button>
```

Calling `import()` multiple times for the same module is safe — the module is only loaded once and cached. This technique eliminates the perceived delay for predictable navigation flows.

For route-based lazy loading in Next.js, `router.prefetch('/heavy-page')` does this at the router level.

## Waterfall Loading (Sequential Lazy Components)

A parent lazy component that renders child lazy components creates a waterfall: the parent loads, renders, then the child's load starts. This doubles the perceived load time.

```tsx
// Bad: child load starts only after parent loads
const Parent = lazy(() => import('./Parent')); // loads first
// Inside Parent:
const Child = lazy(() => import('./Child'));   // loads second, after parent
```

Fix by hoisting all the lazy imports to the same level, or by initiating child imports eagerly when you know the parent will render them:

```tsx
// Start both fetches at module load time
const Parent = lazy(() => import('./Parent'));
const Child = lazy(() => import('./Child'));

// Render both under the same Suspense boundary
<Suspense fallback={<Spinner />}>
  <Parent />
  <Child />
</Suspense>
```

If the child is always rendered inside the parent, move the lazy import up to the file that renders the parent. The browser will fetch both in parallel.

## Key Rules

- **Place `Suspense` close to the lazy component**, not at the page root — isolate loading states to minimize spinner scope.
- **Always provide a same-height placeholder fallback** to prevent layout shift on load.
- **Preload predictable lazy components on hover** — `import('./Module')` on `mouseenter` is zero-cost if the module is already cached.
- **Avoid lazy imports inside lazy components** — waterfall loads compound perceived latency; hoist imports to initiate parallel fetches.
- **Test lazy load behavior on throttled networks** (Chrome DevTools: Slow 3G) — fast connections mask every timing bug.
