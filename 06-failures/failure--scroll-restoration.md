# failure--scroll-restoration.md

Scroll position is managed separately from route state, and most routing libraries don't restore it automatically for all navigation patterns. The result: users navigating back to a long list find themselves at the top; users paginating through results lose their position on re-mount; hard navigations reset to top when soft navigations would have restored.

## Next.js App Router

Next.js App Router does not restore scroll position on back/forward navigation by default. The experimental `scrollRestoration` flag enables browser-native scroll restoration:

```ts
// next.config.ts
experimental: {
  scrollRestoration: true,
}
```

This delegates to `history.scrollRestoration = 'manual'` and uses the History API to save/restore positions. It works for standard page navigations but breaks for pages that load data progressively — the browser restores position before the page is tall enough to scroll to it.

For programmatic navigations using `router.push()`, Next.js scrolls to the top by default. Disable this per-navigation when the URL change is a state update that shouldn't reposition the page:

```ts
router.push('/search?q=foo', { scroll: false });
```

## Infinite Scroll and Virtualized Lists

Infinite scroll lists lose their position completely on back navigation because the list items that were scrolled past no longer exist in the DOM. The browser has nothing to restore to.

The fix requires saving and restoring scroll position manually:

```ts
// On unmount, save scroll position keyed by the current URL
const key = window.location.href;
sessionStorage.setItem(`scroll:${key}`, String(window.scrollY));

// On mount, restore after data loads and DOM is ready
const saved = sessionStorage.getItem(`scroll:${key}`);
if (saved) {
  requestAnimationFrame(() => window.scrollTo(0, parseInt(saved)));
}
```

The `requestAnimationFrame` delay ensures the DOM has rendered enough content to actually scroll to the saved position. For virtualized lists, use the list library's built-in scroll restoration API (TanStack Virtual, `react-window`) rather than `scrollY` — the virtual list controls its own scroll container.

## Scroll-to-Top for Paginated Views

For paginated views (page 1, 2, 3...), the correct behavior on pagination is scroll to top, not scroll restoration. The user is loading a new set of results, not returning to a previous position:

```ts
// When pagination changes, scroll to top
useEffect(() => {
  window.scrollTo({ top: 0, behavior: 'instant' });
}, [page]);
```

Use `behavior: 'instant'` for pagination — smooth scroll on pagination makes it feel slow and disorients users who clicked a page number.

## Smooth Scroll vs Instant

- **Back/forward navigation**: use `behavior: 'instant'` — restoring a previous position should feel immediate.
- **Anchor links / same-page navigation**: use `behavior: 'smooth'` — the movement communicates spatial relationship.
- **Pagination / route change to new content**: use `behavior: 'instant'` — the content is different enough that smooth scroll adds no context.
- **"Scroll to top" button**: use `behavior: 'smooth'` — the user explicitly triggered a long movement.

Never use smooth scroll for programmatic navigations triggered by data loading — if data comes in and the page jumps smoothly, users experience unexpected movement that feels like a bug.

## Key Rules

- Enable `experimental.scrollRestoration` in Next.js config for back/forward scroll memory; combine with manual save/restore for infinite scroll.
- Pass `{ scroll: false }` to `router.push()` when the navigation is a state update that shouldn't move the viewport.
- Infinite scroll lists must save `scrollY` to sessionStorage on unmount and restore after mount + data load.
- Paginate with `scrollTo({ top: 0, behavior: 'instant' })` on page change — not smooth, not restoration.
- Use smooth scroll for user-initiated within-page anchors; use instant for all programmatic restorations.
