# Pattern: CSS Scroll Snap for Card Carousels

Scroll snap creates native-feeling card carousels without JavaScript position tracking. The browser handles momentum, snap points, and touch deceleration. The complexity lives in: peek effect setup, dot indicators synced via Intersection Observer, and not fighting the browser's snap algorithm.

## Why It Matters

JS-driven carousels re-implement what the browser already does well—and they do it worse on low-power devices. CSS scroll snap is hardware-accelerated, respects platform momentum physics, and works with mouse, touch, and keyboard navigation out of the box. The only thing JS needs to handle is dot indicators and accessibility.

## Core CSS

```css
/* Scroll container */
.carousel {
  display: flex;
  overflow-x: scroll;
  scroll-snap-type: x mandatory;
  /* Momentum scrolling on iOS */
  -webkit-overflow-scrolling: touch;
  /* Hide scrollbar visually, keep functional */
  scrollbar-width: none;
  gap: 16px;
  /* Peek effect: padding reveals edge of next card */
  padding-inline: 24px;
  scroll-padding-left: 24px;
}

.carousel::-webkit-scrollbar { display: none; }

/* Each card */
.carousel__item {
  flex: 0 0 calc(100% - 48px); /* full width minus padding on both sides */
  scroll-snap-align: start;
  /* Prevent last card from snapping past end */
  scroll-snap-stop: always;
}
```

### `scroll-snap-type: x mandatory` vs `proximity`

- `mandatory` — always snaps to a snap point when scrolling stops. Predictable. Use for card carousels.
- `proximity` — only snaps if the scroll position is near a snap point. Use for long scrollable pages where snapping every section would be intrusive.

### Peek Effect

The `padding-inline` on the container creates visible edges of adjacent cards, signaling that more content exists. `scroll-padding-left` must match so the snap point aligns with the visible card edge, not the container edge.

```css
/* Show ~20px of next card */
.carousel {
  padding-inline: 20px;
  scroll-padding-left: 20px;
}
.carousel__item {
  flex: 0 0 calc(100% - 40px);
}
```

### Multi-Card View

```css
/* Show 1.15 cards on mobile, 2.15 on tablet */
.carousel__item {
  flex: 0 0 min(280px, calc(100vw - 48px));
  scroll-snap-align: start;
}
```

## Dot Indicators via Intersection Observer

Don't track scroll position with `onscroll + Math.round(scrollLeft / cardWidth)`. That's fragile when cards have variable widths or gap. Use Intersection Observer instead—it fires when a card crosses the visibility threshold:

```tsx
function Carousel({ items }) {
  const [activeIndex, setActiveIndex] = useState(0);
  const itemRefs = useRef<(HTMLDivElement | null)[]>([]);

  useEffect(() => {
    const observer = new IntersectionObserver(
      entries => {
        // Find the entry that is most visible
        const visible = entries
          .filter(e => e.isIntersecting)
          .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
        if (visible) {
          const index = itemRefs.current.indexOf(visible.target as HTMLDivElement);
          if (index !== -1) setActiveIndex(index);
        }
      },
      { threshold: 0.6, root: containerRef.current }
    );

    itemRefs.current.forEach(el => el && observer.observe(el));
    return () => observer.disconnect();
  }, [items]);

  return (
    <>
      <div className="carousel" ref={containerRef}>
        {items.map((item, i) => (
          <div
            key={item.id}
            className="carousel__item"
            ref={el => { itemRefs.current[i] = el; }}
          >
            {/* card content */}
          </div>
        ))}
      </div>
      <div className="carousel__dots" role="tablist" aria-label="Carousel position">
        {items.map((_, i) => (
          <button
            key={i}
            role="tab"
            aria-selected={i === activeIndex}
            aria-label={`Item ${i + 1}`}
            className={`dot ${i === activeIndex ? 'dot--active' : ''}`}
            onClick={() => scrollToIndex(i)}
          />
        ))}
      </div>
    </>
  );
}
```

## Programmatic Scroll

```ts
function scrollToIndex(index: number) {
  itemRefs.current[index]?.scrollIntoView({
    behavior: 'smooth',
    block: 'nearest',
    inline: 'start',
  });
}
```

## Keyboard Navigation

The scroll container is not focusable by default. Add `tabIndex={0}` and handle arrow keys:

```tsx
<div
  className="carousel"
  tabIndex={0}
  onKeyDown={e => {
    if (e.key === 'ArrowRight') scrollToIndex(Math.min(activeIndex + 1, items.length - 1));
    if (e.key === 'ArrowLeft')  scrollToIndex(Math.max(activeIndex - 1, 0));
  }}
  role="region"
  aria-label="Image carousel"
>
```

## Key Rules

- **`scroll-snap-type: x mandatory`** for carousels—`proximity` is for page-level scroll.
- **`scroll-padding-left`** must equal the container's `padding-inline-start`—mismatch breaks snap alignment.
- **`-webkit-overflow-scrolling: touch`** enables iOS momentum scrolling.
- **Use Intersection Observer** for active dot detection, not scroll position math.
- **`scroll-snap-stop: always`** on items prevents fast swipes from skipping multiple cards.
- **Add `tabIndex={0}` + arrow key handler** on the container for keyboard users.
- **Never set `overflow: hidden`** on a parent of the scroll container—it disables scrolling.
