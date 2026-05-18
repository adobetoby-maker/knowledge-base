# Pattern: Sticky Sidebar

## Problem

A sidebar should "stick" while the user scrolls through long main content, stop when it reaches the viewport bottom, and scroll internally if the sidebar itself is taller than the viewport. The most common failure mode: `position: sticky` silently stops working because an ancestor has `overflow: hidden` or `overflow: auto`.

## Basic Sticky Sidebar

```tsx
function PageLayout({ sidebar, children }: Props) {
  return (
    <div className="mx-auto max-w-7xl px-4 py-8 lg:grid lg:grid-cols-[1fr_320px] lg:gap-8">
      <main>{children}</main>
      <aside className="hidden lg:block">
        <div className="sticky top-20 max-h-[calc(100vh-5rem)] overflow-y-auto">
          {sidebar}
        </div>
      </aside>
    </div>
  );
}
```

WHY `top-20`: accounts for a fixed header (80px). Without this offset the sidebar overlaps the header when it sticks. Adjust to match your actual header height.

WHY `max-h-[calc(100vh-5rem)]` + `overflow-y-auto`: when the sidebar content is taller than the viewport, it would otherwise overflow off-screen with no way to scroll. This makes the sidebar independently scrollable.

WHY the sticky wrapper is on the `<div>` inside `<aside>`, not on `<aside>` itself: the `<aside>` participates in the CSS Grid layout and must stretch to the grid cell height. The inner div is what sticks.

## Why sticky Fails

`position: sticky` requires every ancestor in the scroll chain to have `overflow: visible` (the default). Any ancestor with `overflow: hidden`, `overflow: auto`, or `overflow: scroll` creates a new scroll container and the sticky element sticks relative to that container, not the page — which usually means it never sticks visibly.

Debug checklist:
```
1. Open DevTools → select the sticky element
2. Walk up the DOM tree, inspect computed overflow on every ancestor
3. The first ancestor with overflow: hidden/auto/scroll is the culprit
4. Change it to overflow: visible (or clip, which doesn't block sticky)
```

`overflow: clip` (CSS 2021) is an alternative to `overflow: hidden` that doesn't create a scroll container — use it when you need to hide overflow but still want sticky to work:

```css
.wrapper {
  overflow: clip; /* hides overflow without creating scroll context */
}
```

## Table of Contents Example

A common use case: sticky ToC that highlights the current section:

```tsx
function StickyToc({ headings }: { headings: { id: string; text: string }[] }) {
  const [active, setActive] = useState('');

  useEffect(() => {
    const observers = headings.map(({ id }) => {
      const el = document.getElementById(id);
      if (!el) return null;
      const io = new IntersectionObserver(
        ([entry]) => { if (entry.isIntersecting) setActive(id); },
        { rootMargin: '-20% 0px -70% 0px' }
      );
      io.observe(el);
      return io;
    });
    return () => observers.forEach(io => io?.disconnect());
  }, [headings]);

  return (
    <nav aria-label="On this page">
      <ul className="space-y-1 text-sm">
        {headings.map(h => (
          <li key={h.id}>
            <a
              href={`#${h.id}`}
              className={h.id === active ? 'font-semibold text-indigo-600' : 'text-gray-500'}
            >
              {h.text}
            </a>
          </li>
        ))}
      </ul>
    </nav>
  );
}
```

## Key Rules

- Apply `sticky top-[N]` to an inner wrapper, not the grid/flex child itself
- `max-h-[calc(100vh-Nrem)] overflow-y-auto` prevents off-screen overflow for tall sidebars
- Any ancestor with `overflow: hidden/auto/scroll` breaks sticky — use `overflow: clip` when you need clipping without breaking stickiness
- On mobile, collapse or hide the sidebar (drawer pattern) rather than stacking it below content
