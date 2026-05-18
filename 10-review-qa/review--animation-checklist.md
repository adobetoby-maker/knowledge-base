# Review: Animation and Motion QA Checklist

## Purpose

Animation bugs are invisible in screenshots and type checks. This checklist guides the manual review process for any UI with motion, scroll effects, or transitions. Always use `record.js` for this review — not screenshots.

## Required: Video Review

```bash
# Run before and after animation changes
node ~/record.js <port> --slow   # 60s for detailed scroll-through
open /tmp/preview/review.mp4
```

Watch for: jerky motion, content jumping, animation triggering at wrong time, elements flashing.

## Performance

- [ ] **No janky scrolling**: Scroll animations run at 60fps, no stuttering
- [ ] **GPU-accelerated properties only**: Animations use `transform` and `opacity` — not `top`, `left`, `width`, `height`, `margin`
- [ ] **will-change used sparingly**: Only on elements that actually animate; removed after animation completes
- [ ] **No animation on page load for main content**: LCP element (hero) should render instantly, not animate in
- [ ] **Reduced motion respected**: `prefers-reduced-motion` disables or reduces animations

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

## Scroll Animations

- [ ] **Trigger point correct**: Elements animate in at the right scroll position, not too early or too late
- [ ] **No layout shift on trigger**: Elements don't shift other content when they animate in
- [ ] **Stagger feels right**: Staggered children have enough delay to be perceptible but not so much they feel slow
- [ ] **Once only (for entry animations)**: `once: true` in Framer Motion or IntersectionObserver — elements don't re-animate when scrolling back up (unless intentional)

```tsx
// Framer Motion: animate only on first enter
<motion.div
  initial={{ opacity: 0, y: 20 }}
  whileInView={{ opacity: 1, y: 0 }}
  viewport={{ once: true, margin: '-50px' }}
/>
```

## Hover and Interactive States

- [ ] **Transition has duration**: No instant color/size changes — minimum 150ms transition
- [ ] **Scale transforms feel natural**: Hover scale > 1.05 feels too big for most elements
- [ ] **No layout disruption on hover**: Hover effects don't push surrounding content
- [ ] **Focus states visible**: Keyboard focus shows a ring or outline, never animated away

## Framer Motion Specific

- [ ] **No AnimatePresence without key prop**: Exit animations require a unique `key` on the child
- [ ] **No initial=false when SSR**: Setting `initial={false}` skips initial animation — verify this is intentional
- [ ] **Spring constants feel right**: Default spring is bouncy; use `type: 'tween'` for UI that should feel controlled
- [ ] **No motion components on large lists**: Animating 100+ items at once causes frame drops; virtualize first

## Scroll Story / Parallax

- [ ] **Parallax depth is subtle**: > 20% speed difference between layers looks broken
- [ ] **No overflow-hidden cutting off parallax**: Content moving faster than the container clips unnaturally
- [ ] **Pinned sections release correctly**: After a scroll-pinned section, scroll continues normally
- [ ] **Progress indicators sync with scroll**: If a progress bar tracks scroll, verify it's linear and accurate

## Mobile

- [ ] **Touch scrolling not blocked**: `overflow-auto` containers support touch scroll; no `touch-action: none` without reason
- [ ] **Tap targets not reduced by animation**: Animated elements that are also interactive maintain their hit area
- [ ] **iOS Safari specific**: Test momentum scrolling, sticky elements, viewport height (`dvh` vs `vh`)

## Three.js / WebGL

- [ ] **Canvas resize handler**: Canvas redraws on window resize — no stale size after viewport change
- [ ] **Animation loop cleanup**: `requestAnimationFrame` loop is cancelled on component unmount (no memory leak)
- [ ] **Fallback for no WebGL**: Shows a static image or simplified UI when WebGL is unavailable

```tsx
useEffect(() => {
  let frameId: number
  function animate() {
    frameId = requestAnimationFrame(animate)
    renderer.render(scene, camera)
  }
  animate()
  return () => cancelAnimationFrame(frameId)  // Cleanup
}, [])
```
