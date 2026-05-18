# Pattern: Skeleton Loading for Card Grids

## Overview
Skeleton screens reduce perceived load time by giving the user an immediate visual structure that matches the incoming content. The key insight is that a skeleton communicates "this is where content will go" — it must match the layout, proportions, and count of real cards closely enough to prevent jarring reflow when content arrives. Arbitrary placeholder shapes that differ significantly from the real layout are just as disorienting as a blank screen.

## Implementation

### Skeleton Card Component
```tsx
function SkeletonCard() {
  return (
    <div
      aria-hidden="true"   // hide from screen readers — they get the real content
      style={{
        borderRadius: 8,
        overflow: 'hidden',
        background: '#fff',
        border: '1px solid #e5e7eb',
      }}
    >
      {/* Image placeholder — same aspect ratio as real card images */}
      <div style={{ aspectRatio: '16/9', background: '#f3f4f6' }} className="shimmer" />

      <div style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 8 }}>
        {/* Title — full width */}
        <div style={{ height: 16, borderRadius: 4, background: '#f3f4f6', width: '85%' }} className="shimmer" />

        {/* Subtitle — slightly shorter */}
        <div style={{ height: 14, borderRadius: 4, background: '#f3f4f6', width: '60%' }} className="shimmer" />

        {/* Meta line — short */}
        <div style={{ height: 12, borderRadius: 4, background: '#f3f4f6', width: '40%' }} className="shimmer" />

        {/* Button placeholder */}
        <div style={{ height: 36, borderRadius: 6, background: '#f3f4f6', marginTop: 8 }} className="shimmer" />
      </div>
    </div>
  );
}
```

### Shimmer Animation
```css
@keyframes shimmer {
  0%   { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}

.shimmer {
  background-image: linear-gradient(
    90deg,
    #f3f4f6 25%,
    #e5e7eb 50%,
    #f3f4f6 75%
  );
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite linear;
}
```

### Grid with Skeletons
```tsx
function CardGrid({ items, loading }: { items: Item[]; loading: boolean }) {
  // Show 6 skeleton cards — matches a typical first page of results
  // Never show more skeletons than the actual page size
  const SKELETON_COUNT = 6;

  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
        gap: 16,
      }}
    >
      {loading ? (
        <>
          {/* Screen reader announcement */}
          <span role="status" className="sr-only">Loading content...</span>
          {Array.from({ length: SKELETON_COUNT }, (_, i) => (
            <SkeletonCard key={i} />
          ))}
        </>
      ) : (
        items.map(item => <RealCard key={item.id} item={item} />)
      )}
    </div>
  );
}
```

### Matching Proportions
The skeleton card must use the same grid column width and gap as real cards. If real cards have a fixed 200px image height, the skeleton image placeholder must also be 200px. Check against the real card on various viewport sizes.

### Slight Width Randomization
Makes skeleton text lines look more natural:
```tsx
// Pre-compute widths to avoid changing on re-render
const widths = useMemo(() =>
  Array.from({ length: SKELETON_COUNT }, () => ({
    title: `${70 + Math.random() * 20}%`,
    subtitle: `${45 + Math.random() * 20}%`,
    meta: `${30 + Math.random() * 15}%`,
  })),
  [] // only compute once per mount
);
```

### Transition from Skeleton to Real Content
Avoid layout shift when content arrives:
```tsx
// Fade in real content to mask any minor dimension differences
<div
  style={{
    opacity: loading ? 0 : 1,
    transition: loading ? 'none' : 'opacity 200ms ease',
    position: 'absolute', // or use visibility: hidden during load
  }}
>
```

### Empty State vs Loading State
These are distinct states — don't show a skeleton if the user is on page 2 and pagination fails:
```tsx
if (loading && items.length === 0) return <SkeletonGrid />;       // initial load
if (!loading && items.length === 0) return <EmptyState />;         // genuinely empty
if (loading && items.length > 0) return <CardGrid items={items} />; // paginating (show real)
```

## Key Rules
- Skeleton count must not exceed page size — showing 12 skeletons for a 6-item page causes reflow.
- `aria-hidden="true"` on all skeleton elements — screen readers announce the `role="status"` message instead.
- Match real card dimensions as closely as possible — different proportions cause visible reflow on content load.
- Shimmer animation must use `background-position` animation, not `opacity` — opacity flicker reads as error states.
- Skeleton cards use the same grid styles as real cards — never separate grid containers for skeleton vs real.
- Pre-compute randomized line widths outside the render loop — changing them per-render defeats memoization.
- Avoid showing skeletons on paginated loads (page 2+) — the existing content is visible; show a subtle spinner instead.
