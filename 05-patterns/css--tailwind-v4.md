# Tailwind v4 — What Changed and How to Use It

**When:** Working with Tailwind CSS in any project.
**Rule:** Tailwind v4 uses a CSS-first config model. The old `tailwind.config.js` approach still works but the new way is more powerful. Understand which version is installed before writing config.

## Check Which Version
```bash
npx tailwindcss --version
# v3.x = old config model
# v4.x = new CSS-first model
```

## v4 Key Changes from v3

### Config is now in CSS, not JS
```css
/* v4: tailwind.css or globals.css */
@import "tailwindcss";

/* Custom theme tokens */
@theme {
  --color-brand: #3b82f6;
  --font-display: "Inter", sans-serif;
  --spacing-18: 4.5rem;
}

/* Custom utilities */
@utility glass {
  background: rgba(255, 255, 255, 0.08);
  backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.12);
}
```

### v3 `tailwind.config.js` still works (compatibility mode)
If a project has `tailwind.config.js`, it's v3 or v4 in compat mode. Don't change it unless migrating.

### Custom classes in v4
```css
/* Define a custom utility */
@utility flex-center {
  display: flex;
  align-items: center;
  justify-content: center;
}
/* Use it: <div class="flex-center"> */
```

## Arbitrary Values (both v3 and v4)
```jsx
// Any CSS value in square brackets
<div className="w-[73px] bg-[#1a2b3c] top-[calc(100%-2rem)]" />
// Use sparingly — prefer named tokens
```

## Dark Mode (both versions)
```jsx
// Class-based dark mode (set in config)
<div className="bg-white dark:bg-gray-900 text-gray-900 dark:text-white" />

// System preference (no class needed in v4)
<div className="bg-white @media(prefers-color-scheme:dark):bg-gray-900" />
```

## Responsive Prefix Pattern
```jsx
// Mobile-first (correct)
<div className="text-sm md:text-base lg:text-lg" />

// Breakpoints: sm(640) md(768) lg(1024) xl(1280) 2xl(1536)
```

## Common Gotchas

### Class not applying
1. Check: is Tailwind scanning this file? Check `content` in config or `@source` in v4.
2. Check: typo in class name?
3. Check: class is being overridden by more specific CSS

### Purging removes needed classes
If a class is dynamically constructed, it gets purged:
```typescript
// WRONG — purged because no static class string
const color = isError ? 'red' : 'blue'
<div className={`text-${color}-500`} />

// RIGHT — full class names present in source
const className = isError ? 'text-red-500' : 'text-blue-500'
<div className={className} />
```

### Specificity conflicts
Tailwind uses low specificity. Your custom CSS overrides it:
```css
/* Your CSS */
.button { background: blue; }

/* Tailwind */
<button class="button bg-red-500">  // bg-red-500 loses to .button
```
Fix: use `@layer utilities` or increase Tailwind class specificity with `!important` prefix (`!bg-red-500`).
