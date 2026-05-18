# Failure: Tailwind Classes Not Applied

## Overview
Tailwind's JIT (Just-In-Time) compiler generates CSS only for classes it finds in source files at build time. If a class string is assembled dynamically (string concatenation, template literals, variable lookups), the compiler never sees the complete class name and doesn't generate the CSS. The result: the class appears in the HTML but has no styles. The fix is to use complete class names in source code and configure `content` globs to cover every file where Tailwind classes appear.

## The Core Rule: Complete Strings Only

```tsx
// BAD — class name assembled at runtime, JIT never sees 'text-red-500' or 'text-green-500'
const color = isError ? 'red' : 'green'
return <p className={`text-${color}-500`}>Message</p>

// GOOD — complete class names present in source
return <p className={isError ? 'text-red-500' : 'text-green-500'}>Message</p>
```

The JIT scanner reads source code as text, not as JavaScript. It looks for complete class name strings. It does not execute the code.

## Common Dynamic Class Patterns That Break

```tsx
// BAD — variable holding partial class
const variants = { primary: 'blue', danger: 'red' }
const buttonClass = `bg-${variants[type]}-500`  // JIT sees 'bg-${variants[type]}-500' — no match

// GOOD — map to complete classes
const variantClasses = {
  primary: 'bg-blue-500 hover:bg-blue-600',
  danger: 'bg-red-500 hover:bg-red-600',
}
const buttonClass = variantClasses[type]

// BAD — computed property access
const size = { sm: 'p-2', md: 'p-4', lg: 'p-6' }
<div className={size[currentSize]}>  // This WORKS if the values are complete strings

// GOOD — the above actually works! The value 'p-2' is a complete string in source
```

The rule applies to construction, not lookup. If the complete class string appears somewhere in source, it's safe.

## `content` Configuration Must Cover All Files

```js
// tailwind.config.js
module.exports = {
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',     // App Router
    './pages/**/*.{js,ts,jsx,tsx,mdx}',    // Pages Router
    './components/**/*.{js,ts,jsx,tsx}',
    './lib/**/*.{js,ts}',                  // Utility functions with className logic
    './src/**/*.{js,ts,jsx,tsx}',          // src directory if used
  ],
  // ...
}
```

Missing a directory = any classes in that directory won't generate CSS. Common misses:
- `lib/` — utility functions that return className strings
- `config/` — theme/variant config objects with class names
- `stories/` — Storybook stories
- Monorepo packages — `../../packages/**/*.tsx`

## Safelist for Truly Dynamic Classes

When classes are genuinely dynamic (from a database, user config, CMS), add them to safelist:

```js
// tailwind.config.js
module.exports = {
  safelist: [
    // Exact classes
    'text-red-500',
    'text-green-500',
    // Pattern matching
    {
      pattern: /^(bg|text|border)-(red|green|blue|yellow)-(100|500|900)$/,
    },
    // All variants of a pattern
    {
      pattern: /^bg-/,
      variants: ['hover', 'focus'],
    },
  ],
}
```

Avoid safelisting broadly — it defeats JIT's bundle size optimization.

## Third-Party Component Libraries

If using a component library that uses Tailwind classes internally (Flowbite, shadcn, etc.), include its source in `content`:

```js
content: [
  './node_modules/flowbite-react/**/*.{js,ts,jsx,tsx}',
  // shadcn components are in your project, not node_modules
  './components/ui/**/*.{js,ts,jsx,tsx}',
],
```

## Verifying the Issue

```bash
# Build and search for missing class in CSS output
npm run build
grep -r "text-red-500" .next/static/css/  # should find it if JIT picked it up

# Or: use Tailwind's debug output
npx tailwindcss -i input.css -o output.css --content "./src/**/*.tsx"
```

If the class isn't in the output CSS, either the file containing it isn't in `content`, or the class name is assembled dynamically.

## Key Rules
- Tailwind class names must appear as complete, unbroken strings in source files
- Never assemble class names with string concatenation or template literals
- Use an object map to translate variants to complete class strings
- After adding a new file path pattern, rebuild — JIT only scans files at build time
- Safelist is for dynamic classes from external sources (CMS, user config) — not for laziness
- `content` paths should include every file that can produce a className string, including utility functions
- In development with `next dev`, class changes hot-reload; missing `content` paths fail silently until prod
