# Pattern: Shimmer / Skeleton Loading Effect

## Overview

Skeleton screens replace blank white flashes during loading. A shimmer animation makes them feel active rather than broken. The key insight: skeleton elements should match the shape and size of real content — a skeleton that's a different size than the loaded content causes layout shift.

## CSS Shimmer Animation

```css
/* globals.css or tailwind plugin */
@keyframes shimmer {
  0% { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}

.skeleton {
  background: linear-gradient(
    90deg,
    #f0f0f0 25%,
    #e0e0e0 50%,
    #f0f0f0 75%
  );
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
  border-radius: 4px;
}
```

In Tailwind v4, add as a CSS custom animation:

```css
@theme {
  --animate-shimmer: shimmer 1.5s infinite;
}

@keyframes shimmer {
  0% { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}
```

## Skeleton Components

```tsx
function SkeletonText({ className }: { className?: string }) {
  return <div className={cn('skeleton h-4 rounded', className)} />
}

function SkeletonAvatar({ size = 40 }: { size?: number }) {
  return (
    <div
      className="skeleton rounded-full flex-shrink-0"
      style={{ width: size, height: size }}
    />
  )
}

function SkeletonButton({ className }: { className?: string }) {
  return <div className={cn('skeleton h-9 rounded-md', className)} />
}
```

## Post Card Skeleton

```tsx
function PostCardSkeleton() {
  return (
    <div className="p-4 border border-gray-200 rounded-lg space-y-3">
      {/* Avatar + author line */}
      <div className="flex items-center gap-3">
        <SkeletonAvatar size={32} />
        <div className="space-y-1.5 flex-1">
          <SkeletonText className="w-32" />
          <SkeletonText className="w-20 h-3" />
        </div>
      </div>
      {/* Title */}
      <SkeletonText className="w-3/4 h-5" />
      {/* Body lines */}
      <div className="space-y-2">
        <SkeletonText />
        <SkeletonText />
        <SkeletonText className="w-2/3" />
      </div>
      {/* Image placeholder */}
      <div className="skeleton h-48 rounded-lg" />
    </div>
  )
}
```

## List with Multiple Skeletons

```tsx
function PostListSkeleton({ count = 3 }: { count?: number }) {
  return (
    <div className="space-y-4">
      {Array.from({ length: count }, (_, i) => (
        <PostCardSkeleton key={i} />
      ))}
    </div>
  )
}
```

## Usage with Suspense

```tsx
// React Suspense automatically shows fallback during async data loading
<Suspense fallback={<PostListSkeleton count={5} />}>
  <PostList />
</Suspense>
```

## Conditional Loading State

```tsx
function Dashboard() {
  const { data: stats, isLoading } = useSWR('/api/stats', fetcher)

  return (
    <div className="grid grid-cols-3 gap-4">
      {isLoading ? (
        Array.from({ length: 3 }, (_, i) => (
          <div key={i} className="p-6 rounded-lg border">
            <SkeletonText className="w-24 h-3 mb-3" />
            <SkeletonText className="w-16 h-8" />
          </div>
        ))
      ) : (
        stats?.map(stat => <StatCard key={stat.label} {...stat} />)
      )}
    </div>
  )
}
```

## Dark Mode Support

```css
/* In dark mode the shimmer should use darker tones */
.dark .skeleton {
  background: linear-gradient(
    90deg,
    #2a2a2a 25%,
    #333333 50%,
    #2a2a2a 75%
  );
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}
```

Or with Tailwind:

```tsx
<div className="skeleton dark:skeleton-dark" />
```

## Respecting Reduced Motion

```css
@media (prefers-reduced-motion: reduce) {
  .skeleton {
    animation: none;
    background: #f0f0f0;
  }
}
```

## Key Rules

- Skeleton dimensions must match the real content dimensions — wrong sizes cause cumulative layout shift (CLS), hurting both UX and Core Web Vitals.
- Use `Array.from({ length: n })` to render N skeletons — `new Array(n).fill(0)` is equivalent but less readable.
- Only animate shimmer when the page is visible: `document.hidden` check prevents animating background tabs unnecessarily.
- For tables, skeleton rows must have the same column widths as real rows — use the same `grid-cols` or `table` layout.
- Show skeletons immediately, not after a 200ms delay — perceived performance is better with immediate feedback even for fast loads.
