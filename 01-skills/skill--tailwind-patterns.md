# Skill: tailwind-patterns

**Trigger:** Writing Tailwind CSS v4. Need responsive layouts, complex spacing, dark mode, custom utilities, or production-quality visual polish.
**Invoke:** `/tailwind-patterns`
**Returns:** Tailwind v4 CSS-first config, utility patterns, responsive system, animation, dark mode.

## When to Invoke
- Setting up Tailwind in a new project (v4 config differs from v3)
- Need responsive breakpoint patterns beyond simple `md:` prefixes
- Building complex grid or flex layouts
- Adding dark mode support
- Creating custom design tokens
- Need container queries

## Tailwind v4 Key Changes
v4 is CSS-first. No more `tailwind.config.js` for most things.

```css
/* globals.css — v4 config lives here */
@import "tailwindcss";

@theme {
  --color-brand: oklch(58% 0.2 264);
  --font-display: "Cal Sans", sans-serif;
  --spacing-18: 4.5rem;
  --radius-xl: 1rem;
}
```

## Responsive Layout Patterns

### The Safe Container Pattern
```html
<div class="mx-auto w-full max-w-7xl px-4 sm:px-6 lg:px-8">
```

### Responsive Grid
```html
<!-- 1 col mobile → 2 col tablet → 3 col desktop -->
<div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
```

### Sidebar Layout
```html
<div class="flex flex-col gap-8 lg:flex-row">
  <aside class="w-full lg:w-64 lg:shrink-0">...</aside>
  <main class="min-w-0 flex-1">...</main>
</div>
```

## Spacing System
Use multiples of 4 (1rem = 16px):
- `p-4` = 1rem (16px) — card inner padding mobile
- `p-6` = 1.5rem (24px) — card inner padding desktop
- `gap-8` = 2rem (32px) — section element spacing
- `py-16` = 4rem (64px) — section vertical padding
- `py-24` = 6rem (96px) — hero section

## Dark Mode
```css
/* globals.css */
@variant dark (&:is(.dark *));
```
```html
<div class="bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100">
```
Toggle: `document.documentElement.classList.toggle('dark')`

## Animation Utilities
```html
<!-- Fade in on load -->
<div class="animate-fade-in">
<!-- Slide up -->
<div class="animate-slide-up">
<!-- Spin (loading) -->
<div class="animate-spin">
```
Custom animations defined in `@theme` block in globals.css.

## Common Gotchas
- Dynamic class names don't work: `text-${color}-500` is NOT purged correctly — use full class names
- v4 uses `@import "tailwindcss"` not `@tailwind base/components/utilities` directives
- `gap` in flex needs parent `flex` class — it doesn't apply to `display: block`

## What Skill Returns
Full v4 config patterns, utility composition, responsive strategies, component class collections, production polish techniques.
