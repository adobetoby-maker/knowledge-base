# Category Navigation with Active State

## The Core Problem

Category nav needs to do three things simultaneously: highlight the section currently in the viewport, scroll to a section when its nav item is clicked, and keep the URL hash in sync — all without fighting each other. Most implementations break because the scroll-to-section click handler briefly activates the wrong nav item before the scroll settles.

## Intersection Observer for Active Section

Don't track scroll position with `window.addEventListener('scroll')` — it fires constantly and forces layout reads. Use `IntersectionObserver` to detect which section enters or exits the viewport.

```tsx
useEffect(() => {
  const sections = document.querySelectorAll('[data-section]')
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          setActiveSection(entry.target.getAttribute('data-section') ?? '')
        }
      })
    },
    {
      rootMargin: '-20% 0px -70% 0px',  // trigger when section is in upper 30% of viewport
      threshold: 0,
    }
  )
  sections.forEach(s => observer.observe(s))
  return () => observer.disconnect()
}, [])
```

`rootMargin: '-20% 0px -70% 0px'` is the critical setting. It means the intersection fires when a section enters a band from 20% from top to 30% from bottom. Without this, the active state flickers when two sections are both partially visible.

## Click Scrolls to Section

```tsx
const scrollToSection = (id: string) => {
  // Temporarily disable observer to avoid flicker during programmatic scroll
  setIsScrolling(true)
  setActiveSection(id)  // update immediately on click

  document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' })

  // Re-enable observer after scroll settles (~600ms for smooth scroll)
  setTimeout(() => setIsScrolling(false), 700)
}
```

The `isScrolling` guard prevents the observer from overriding the click-selected active state while the smooth scroll is in progress. Without it, clicking "Section 3" may briefly flash "Section 1" as the currently-visible section during the scroll.

## URL Hash Sync

Sync the hash on scroll, not on click. On click, update immediately; let the observer update the hash as sections come into view.

```tsx
// In the observer callback:
if (entry.isIntersecting && !isScrolling) {
  setActiveSection(id)
  history.replaceState(null, '', `#${id}`)  // replaceState, not pushState — avoid polluting history
}
```

Use `replaceState` not `pushState` — every scroll shouldn't create a new browser history entry.

On page load, read the initial hash and scroll to that section after a short delay (wait for layout):

```tsx
useEffect(() => {
  const id = window.location.hash.slice(1)
  if (id) setTimeout(() => document.getElementById(id)?.scrollIntoView(), 100)
}, [])
```

## Mobile: Horizontal Scroll with overflow-x

Category nav on mobile typically renders as a horizontal strip that scrolls. Key details:

```css
.category-nav {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;  /* momentum scrolling on iOS */
  scrollbar-width: none;              /* hide scrollbar on Firefox */
}
.category-nav::-webkit-scrollbar { display: none; }  /* hide on Chrome/Safari */
```

Auto-scroll the nav strip so the active item stays centered when the section changes via scroll:

```tsx
useEffect(() => {
  const activeEl = navRef.current?.querySelector(`[data-nav="${activeSection}"]`)
  activeEl?.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' })
}, [activeSection])
```

`inline: 'center'` centers the active nav item horizontally within the strip without disrupting the page's vertical scroll.

## Sticky Positioning

Category nav usually sticks to the top of the viewport. Account for it in section scroll targets — if the nav is 56px tall, sections need `scroll-margin-top: 56px` so they don't hide behind the nav after clicking.

```css
[data-section] {
  scroll-margin-top: 56px;  /* height of sticky nav */
}
```

## Key Rules

- Use `IntersectionObserver` with a non-trivial `rootMargin`, not scroll listeners — this avoids forced layout and flicker
- Set `isScrolling` guard during programmatic scroll to prevent observer from overriding the click-selected state
- Use `history.replaceState` not `pushState` for hash updates — hash-per-scroll position pollutes the browser history
- Set `scroll-margin-top` on sections equal to sticky nav height — otherwise sections anchor behind the nav header
- On mobile, auto-scroll the nav strip (`inline: 'center'`) to keep the active item visible — don't rely on the user knowing to scroll the nav manually
