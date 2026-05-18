# Failure Patterns: Tailwind v4 Breaking Changes

## CSS-First Configuration (No More tailwind.config.js)

Tailwind v4 moves configuration into CSS. There is no `tailwind.config.js` or `tailwind.config.ts`.

```css
/* WRONG — tailwind.config.ts with extend.colors doesn't work in v4 */

/* CORRECT — define in CSS: */
@import "tailwindcss";

@theme {
  --color-brand: #2563eb;
  --color-brand-foreground: #ffffff;
  --font-heading: "Inter", sans-serif;
  --spacing-section: 4rem;
}
```

Then use in JSX:
```typescript
<div className="bg-brand text-brand-foreground" />
<h1 className="font-heading" />
<section className="py-section" />
```

## No More `@apply` in Component CSS

`@apply` still works but is discouraged in v4. Prefer composing utilities directly in JSX. For base resets in CSS:
```css
/* If you must use @apply, it still works: */
.btn {
  @apply px-4 py-2 rounded-md font-medium;
}
```

But the preferred v4 pattern is composition in JSX using `cn()` or component variants.

## JIT Is Always On (No Safelist Needed)

In v3, you might add classes to `safelist` for dynamic generation. In v4, JIT scans all files automatically — no safelist needed:
```typescript
// Dynamic class names — v4 handles these IF the full class string appears somewhere:
const color = 'blue'
// WRONG: className={`text-${color}-500`}  — class string never appears in source
// CORRECT: const classes = { blue: 'text-blue-500', red: 'text-red-500' }
// Then: className={classes[color]}
```

This behavior is the same as v3 JIT — full class strings must appear in source.

## Opacity Utilities Changed

v3: `bg-blue-500/50` — opacity on the color
v4: Same syntax works, but the underlying implementation changed. `opacity-*` standalone utilities are removed:
```
v3: opacity-50  → still works as a standalone utility in v4
v4: bg-blue-500/50  → preferred for color + opacity
```

## Dark Mode Configuration

```css
/* v4 — configure dark mode variant in CSS: */
@import "tailwindcss";
@variant dark (&:where(.dark, .dark *));
```

Then: `dark:bg-gray-900` works as before.

## Container Queries Available

New in v4 — container queries use `@` prefix:
```typescript
// Parent must be a container:
<div className="@container">
  {/* Child responds to parent width, not viewport: */}
  <p className="text-sm @md:text-base @lg:text-xl">Responsive text</p>
</div>
```

## Breakpoint Changes

v4 introduces `3xl` (1920px) and adjusts some values. Existing md/lg/xl/2xl still work. Check if `2xl:` was used for large monitor layouts.

## Plugin API Changed

Third-party Tailwind plugins written for v3 may not work in v4. Check plugin compatibility before upgrading projects that rely on plugins like `@tailwindcss/typography`, `@tailwindcss/forms`.

```bash
# Check if typography plugin is v4 compatible:
npm show @tailwindcss/typography version
# v0.5.x is for Tailwind v3
# v4-compatible versions will have different version range
```

## Using Tailwind v4 with Next.js

```css
/* globals.css */
@import "tailwindcss";

/* shadcn variables go here too: */
@theme {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  /* etc. */
}
```

```typescript
// next.config.ts — no special Tailwind config needed
// PostCSS config: just @tailwindcss/postcss (no autoprefixer needed, built-in)
```

## What Didn't Change

- All utility class names remain the same
- Responsive prefixes (`md:`, `lg:`) unchanged
- State variants (`hover:`, `focus:`, `disabled:`) unchanged
- `cn()` / `clsx` usage unchanged
- shadcn/ui components work (they updated their templates for v4)
