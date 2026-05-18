# Failure: Janky Animation Performance

## Overview
Animations that stutter, drop frames, or cause visible jank are almost always caused by animating CSS properties that trigger browser layout recalculation. The browser rendering pipeline has three stages: Layout (compute element positions and sizes), Paint (draw pixels), and Composite (combine layers). Only `transform` and `opacity` skip Layout and Paint entirely — they run only on the GPU compositor thread and never block the main thread. Animating anything else creates visible jank.

## The GPU-Composited Properties

These are the ONLY properties that animate without triggering Layout:

```css
/* Safe to animate — GPU compositor only */
transform: translateX(100px);
transform: scale(1.2);
transform: rotate(45deg);
opacity: 0.5;
```

Everything else triggers Layout (expensive) or at minimum Paint (expensive):
```css
/* All of these cause Layout recalculation — never animate */
width, height          /* layout */
top, left, right, bottom /* layout (use transform: translate instead) */
margin, padding        /* layout */
border-width           /* layout */
font-size              /* layout */
color, background-color /* paint (not layout, but still expensive) */
box-shadow             /* paint */
```

## Translating "Natural" Animations to GPU-Safe Ones

```css
/* Wrong: sliding in from left — animates 'left' */
.sidebar {
  position: absolute;
  left: -300px;
  transition: left 0.3s ease;
}
.sidebar.open { left: 0; }

/* Right: sliding in from left — animates 'transform' */
.sidebar {
  position: absolute;
  transform: translateX(-300px);
  transition: transform 0.3s ease;
}
.sidebar.open { transform: translateX(0); }
```

```css
/* Wrong: expand/collapse height — triggers layout on every frame */
.accordion {
  height: 0;
  overflow: hidden;
  transition: height 0.3s ease; /* DON'T animate height */
}

/* Right: use max-height or clip-path, or transition opacity+transform */
.accordion {
  max-height: 0;
  overflow: hidden;
  transition: max-height 0.3s ease; /* better but still causes layout */
}

/* Best: for pure visual expand, use clip-path */
.accordion {
  clip-path: inset(0 0 100% 0);
  transition: clip-path 0.3s ease; /* compositor-only */
}
```

## will-change: Use Sparingly

`will-change: transform` hints to the browser to promote an element to its own GPU layer before the animation starts, eliminating the layer promotion cost at animation start. But each promoted layer consumes GPU memory:

```css
/* Use only on elements that animate frequently */
.carousel-item {
  will-change: transform; /* OK: animates on every slide */
}

/* Never apply globally */
* { will-change: transform; } /* WRONG: GPU memory exhaustion */

/* Remove after animation completes */
.element.animation-done {
  will-change: auto; /* release GPU layer */
}
```

## Framer Motion — Performance Patterns

```typescript
// Wrong: animating layout-affecting properties
<motion.div animate={{ width: "100%", height: "200px" }} />

// Right: use transform
<motion.div animate={{ scaleX: 1, scaleY: 1 }} />
<motion.div animate={{ x: 0, y: 0 }} />
<motion.div animate={{ opacity: 1 }} />

// layout prop triggers FLIP animation (layout-aware but optimized)
<motion.div layout animate={{ opacity: 1 }} />
// Use layout prop for reordering lists — it handles the layout change correctly
```

## Measuring Animation Performance

```
Chrome DevTools → Performance panel → Record during animation
Look for:
- Long frames (> 16ms for 60fps) → shown as red in timeline
- "Recalculate Style" and "Layout" events → caused by non-transform animations
- "Composite Layers" should be the main activity for smooth animations
```

`content-visibility: auto` on sections below the fold reduces Paint work:
```css
.below-fold-section {
  content-visibility: auto;
  contain-intrinsic-size: 0 800px; /* estimated height to prevent layout shift */
}
```

## Key Rules
- Only animate `transform` and `opacity` — nothing else
- Replace position animations (`top`, `left`) with `transform: translate()`
- Replace size animations (`width`, `height`) with `transform: scale()` where possible
- `will-change: transform` on frequently animating elements, never globally
- Remove `will-change` after animation completes to release GPU memory
- Profile with Chrome DevTools Performance panel before declaring animation "smooth"
- Check on a throttled CPU (4x slowdown in DevTools) — 60fps on M2 MacBook is not production
- Reduce motion for accessibility: `@media (prefers-reduced-motion: reduce)`
