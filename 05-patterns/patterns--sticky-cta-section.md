# Pattern: Sticky Call-to-Action Bar

## Overview
A sticky CTA bar appears as the user scrolls past the hero section — at that point the hero's primary CTA is no longer visible but the user has shown engagement by continuing to read. The bar disappears when the user scrolls back to the top where the hero CTA is visible, preventing redundancy. IntersectionObserver is the correct tool for this — `scroll` event listeners with `getBoundingClientRect()` are less efficient and require manual throttling.

## Implementation

### IntersectionObserver Setup
```tsx
import { useEffect, useRef, useState } from 'react'

function useStickyBarVisibility(heroRef: React.RefObject<HTMLElement>) {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    const hero = heroRef.current
    if (!hero) return

    const observer = new IntersectionObserver(
      ([entry]) => {
        // Bar shows when hero exits viewport, hides when hero is visible
        setVisible(!entry.isIntersecting)
      },
      {
        // Trigger as soon as the hero fully leaves the viewport
        threshold: 0,
        // Negative bottom margin means the hero must fully scroll out
        rootMargin: '0px 0px 0px 0px',
      }
    )

    observer.observe(hero)
    return () => observer.disconnect()
  }, [heroRef])

  return visible
}
```

### Sticky CTA Bar
```tsx
function StickyCTABar({
  heroRef,
  ctaLabel,
  ctaHref,
  valueProposition,
}: {
  heroRef: React.RefObject<HTMLElement>
  ctaLabel: string
  ctaHref: string
  valueProposition: string
}) {
  const visible = useStickyBarVisibility(heroRef)

  return (
    <div
      aria-hidden={!visible}
      className={[
        'fixed bottom-0 inset-x-0 z-40',
        'bg-white border-t shadow-lg px-4 py-3',
        'flex items-center justify-between gap-4',
        'transform transition-transform duration-300 ease-in-out',
        visible ? 'translate-y-0' : 'translate-y-full',
      ].join(' ')}
    >
      <p className="text-sm text-gray-700 hidden sm:block">{valueProposition}</p>

      <a
        href={ctaHref}
        className="ml-auto whitespace-nowrap px-5 py-2 bg-blue-600 text-white rounded-md text-sm font-semibold hover:bg-blue-700 transition-colors"
        tabIndex={visible ? 0 : -1}  // Remove from tab order when hidden
      >
        {ctaLabel}
      </a>
    </div>
  )
}
```

### Usage with Hero
```tsx
function LandingPage() {
  const heroRef = useRef<HTMLElement>(null)

  return (
    <>
      <section ref={heroRef} className="min-h-screen flex items-center justify-center bg-blue-900">
        <HeroContent />
      </section>

      <section className="py-16 px-4">
        <FeatureSection />
      </section>

      <section className="py-16 px-4 bg-gray-50">
        <TestimonialsSection />
      </section>

      {/* Sticky bar — positioned relative to entire page, not a section */}
      <StickyCTABar
        heroRef={heroRef}
        ctaLabel="Start free trial"
        ctaHref="/signup"
        valueProposition="No credit card required · Cancel anytime"
      />
    </>
  )
}
```

### Mobile-Only Variant
```tsx
// If the bar should only appear on mobile (desktop has sidebar or inline CTA)
function MobileOnlyStickyCTA({ heroRef, ...props }: StickyCTABarProps) {
  const visible = useStickyBarVisibility(heroRef)

  return (
    <div
      className={[
        'md:hidden fixed bottom-0 inset-x-0 z-40 ...',
        visible ? 'translate-y-0' : 'translate-y-full',
      ].join(' ')}
    >
      <CTAContent {...props} />
    </div>
  )
}
```

### Safe Area for Mobile (notch devices)
```tsx
// Account for iOS home indicator
<div
  className="fixed bottom-0 inset-x-0 z-40 bg-white border-t"
  style={{ paddingBottom: 'env(safe-area-inset-bottom)' }}
>
  <div className="px-4 py-3 flex items-center justify-between">
    {/* content */}
  </div>
</div>
```

### Animating with Body Padding Adjustment
```tsx
// Optional: push page content up when bar appears so it doesn't overlap bottom content
function useBodyPadding(visible: boolean, barHeight = 64) {
  useEffect(() => {
    document.body.style.paddingBottom = visible ? `${barHeight}px` : '0px'
    return () => { document.body.style.paddingBottom = '0px' }
  }, [visible, barHeight])
}
```

## Key Rules
- Use IntersectionObserver on the hero element — scroll event listeners are less efficient and harder to manage
- Bar slides UP from the bottom (`translateY: 0`) when visible, slides DOWN (`translateY: 100%`) when not — always animate with `transform`, never with `top`/`bottom` changes
- `aria-hidden={!visible}` prevents screen readers from announcing a hidden CTA bar
- `tabIndex={-1}` on the CTA link when bar is hidden — removes it from the keyboard tab order
- Value proposition on the left, CTA on the right — this matches the reading direction and visual hierarchy
- Hide the value proposition on mobile (show CTA only) — small screen bars get crowded with two elements
- Add `env(safe-area-inset-bottom)` padding for iPhone notch/home-indicator devices
- Never show the sticky bar before the hero exits the viewport — showing it immediately on page load duplicates the hero CTA and wastes attention
