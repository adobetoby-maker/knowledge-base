# Disambiguation: Which CSS Approach?

## Project Defaults

All projects in this workspace use **Tailwind CSS** as the primary styling approach. Never introduce a new CSS-in-JS library, CSS modules, or styled-components unless the project already uses one.

Tailwind v4+ uses CSS-first configuration (no `tailwind.config.js` needed for basic setup). Check if the project is on v3 (config file exists) or v4 (CSS-only config).

## Decision Guide

### Tailwind Utility Classes (Default)

Use for: all component styling, responsive design, states.

```tsx
<button className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md transition-colors">
  Save
</button>
```

### Tailwind + cn() for Dynamic Classes

When combining conditional classes:

```tsx
import { cn } from '@/lib/utils'

<div className={cn(
  'rounded-md px-3 py-2',
  isActive && 'bg-blue-100 text-blue-800',
  isDisabled && 'opacity-50 cursor-not-allowed'
)}>
```

Never concatenate class strings with template literals — Tailwind's purging may remove classes it can't detect as strings.

### CSS Custom Properties for Design Tokens

For values that change (theme, dark mode, brand colors):

```css
/* app/globals.css */
:root {
  --color-primary: 222.2 47.4% 11.2%;
  --border-radius: 0.5rem;
}
```

```tsx
<div style={{ color: 'hsl(var(--color-primary))' }}>
```

### Inline Styles for Dynamic Values

Use inline styles when the value is truly dynamic and can't be a Tailwind class:

```tsx
// A progress bar width based on data
<div style={{ width: `${progress}%` }} className="h-2 bg-blue-500 rounded" />

// A position calculated from scroll
<div style={{ top: `${scrollY * 0.5}px` }} />
```

Don't use inline styles for static values — Tailwind classes are more maintainable.

### Tailwind @layer for Reusable Component Classes

When the same Tailwind combination repeats many times:

```css
/* app/globals.css */
@layer components {
  .btn-primary {
    @apply bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md transition-colors;
  }
  
  .input-field {
    @apply border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500;
  }
}
```

Use sparingly — prefer composing Tailwind in JSX. `@layer components` classes are useful when the same pattern appears 10+ times across many files.

### CSS Animations Beyond Tailwind

For complex animations that Framer Motion handles better:

```tsx
// Framer Motion for: scroll animations, exit animations, layout animations, gestures
// Tailwind animate- for: simple show/hide, loading spinners, simple transitions
```

Tailwind's `animate-spin`, `animate-pulse`, `animate-bounce` cover the common cases. Use Framer Motion for anything that requires `useScroll`, `useTransform`, `AnimatePresence`, or spring physics.

## Dark Mode

All projects use system dark mode via Tailwind's `dark:` variant:

```tsx
<div className="bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
```

The `dark` class is applied to `<html>` element, controlled by the OS preference unless the user has a toggle. Check the root layout for how dark mode is initialized in each project.

## Tailwind v3 vs v4 Differences

Tailwind v4 (CSS-first):
- No `tailwind.config.js` — configuration in `globals.css`
- Different plugin installation: `@import "tailwindcss"` in CSS
- Same utility class API

Tailwind v3 (JS config):
- `tailwind.config.ts` present in project root
- Plugins listed in config
- `@tailwind base/components/utilities` directives in CSS

Check the project's CSS import and config file before adding custom config.
