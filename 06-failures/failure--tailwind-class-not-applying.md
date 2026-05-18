# Failure: Tailwind Class Not Applying

**Symptom:** You add a Tailwind class, nothing changes in the UI. The class appears in the HTML but has no effect.

## Diagnostic Checklist

```
1. Open browser DevTools → inspect element → Styles panel
   → Is the class present but crossed out? → specificity conflict (Fix 1)
   → Is the class absent entirely? → purged or not scanned (Fix 2)
   → Is the class present and active but no effect? → wrong class name (Fix 3)
```

## Fix 1 — Specificity Conflict
Another CSS rule is overriding the Tailwind class.
```css
/* Your globals.css has: */
.card { background: blue; }

/* Tailwind has: */
.bg-red-500 { background-color: rgb(239, 68, 68); }

/* .card wins because it's a class selector too but came later or is more specific */
```

Solutions:
```tsx
// Option A: Use important modifier (Tailwind prefix)
<div className="card !bg-red-500" />

// Option B: Fix the specificity in your CSS
@layer components {
  .card { background: blue; }  /* lower specificity in Tailwind's layer */
}

// Option C: Remove the conflicting CSS rule
```

## Fix 2 — Class Purged (Not Found in Source)
Tailwind scans your source files and only includes classes it finds. Dynamic class construction breaks this.
```typescript
// WRONG — Tailwind can't scan this, class is purged
const color = 'red'
<div className={`text-${color}-500`} />

// RIGHT — full class name present as a string in source
const className = 'text-red-500'
<div className={className} />
```

If you need dynamic classes, use a safelist in `tailwind.config.js`:
```javascript
module.exports = {
  safelist: ['text-red-500', 'text-blue-500', 'text-green-500']
}
```

## Fix 3 — Typo or Wrong Class Name
```
text-grey-500  ← WRONG (grey not in Tailwind)
text-gray-500  ← RIGHT

items-centered ← WRONG
items-center   ← RIGHT

flex-col-reverse ← WRONG
flex-col + rotate? ← need to check docs
```

Use the Tailwind CSS IntelliSense VSCode extension to autocomplete class names.

## Fix 4 — Content Config Missing This File
In `tailwind.config.js`, the `content` array must include all files with Tailwind classes:
```javascript
module.exports = {
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/**/*.{js,ts,jsx,tsx,mdx}',
    // If you have a separate utils/ or lib/ with className strings:
    './lib/**/*.{js,ts}',
  ]
}
```

## Fix 5 — CSS Layer Order (v4 specific)
In Tailwind v4, `@import "tailwindcss"` must come before any custom CSS:
```css
/* WRONG */
.my-class { color: red; }
@import "tailwindcss";

/* RIGHT */
@import "tailwindcss";
.my-class { color: red; }
```

## Fix 6 — Cached Styles
Sometimes the browser is showing cached CSS.
Hard refresh: `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows)
Or in DevTools: right-click reload button → "Empty Cache and Hard Reload"
