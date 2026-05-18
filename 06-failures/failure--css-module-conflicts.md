# Failure: CSS Module Class Name Collisions in Production

## Why CSS Modules Hash Uniqueness Is Not Absolute

CSS Modules generate scoped class names by hashing the filename and the local class name together. In development, the generated class looks like `Button_primary__XkL2p`. In production builds, the hash is compressed — by default to a short alphanumeric string — to save bytes. With thousands of components across multiple packages (especially in a monorepo), short hashes can collide.

The collision symptom: styles from component A apply to component B, or one component's styles suddenly change after an unrelated file is modified (because the hash of a different file happens to produce the same short string).

This is rare with small projects but real at scale. The fix: configure the CSS Modules hash to include more entropy, typically by adding the full file path to the hash input.

In webpack/Next.js:

```js
// next.config.js
module.exports = {
  webpack: (config) => {
    const cssLoader = config.module.rules.find(
      r => r.oneOf?.find(o => o.use?.find(u => u.loader?.includes('css-loader')))
    );
    // Set localIdentName to include path for full uniqueness
    // Next.js manages this internally; for custom configs:
    // localIdentName: '[folder]__[local]--[hash:base64:8]'
    return config;
  },
};
```

For most projects, Next.js's default CSS Module configuration is sufficient. The problem emerges primarily with custom webpack configs that shorten the hash excessively.

## The :global() Trap

CSS Modules only scope class names written as plain classes or `:local()`. When you use `:global(.someClass)`, that class name is not scoped — it applies globally to any element with that class anywhere in the document. This defeats the purpose of CSS Modules and causes real collisions.

Common misuse:

```css
/* BAD — .active is global, conflicts with any other .active in the document */
.wrapper :global(.active) {
  color: blue;
}
```

Use `:global()` only for targeting third-party library classes you don't control (e.g., styling a class name injected by a datepicker library). For your own component states, use a scoped class.

```css
/* GOOD — .active is scoped to this module */
.wrapper.active {
  color: blue;
}
```

## Tailwind vs CSS Modules: When to Choose

CSS Modules are good for: component-specific styles with complex selectors, states that need multiple class combinations, gradual migration from global CSS.

Tailwind is good for: rapid UI work, teams where consistent design system tokens matter, reducing context-switching between files.

The problematic pattern is mixing both inconsistently. Tailwind classes are global by definition; CSS Modules provide local scope. When both are present, specificity battles arise when a Tailwind utility and a CSS Module rule target the same element.

Decision rule: pick one per project boundary. In a Next.js app, if you're using Tailwind, avoid CSS Modules for new components. If you're in a component library that ships CSS, use CSS Modules (consumers may not use Tailwind). Never mix both on the same element.

## Production-Specific Appearance

CSS Module hash collisions and `:global()` issues often appear only in production because:
- Production builds use short hashes; development builds use long readable names
- Production CSS is concatenated and minified, changing specificity order
- Development hot reload may mask a conflict that only manifests in a full build

Always run `npm run build && npm start` locally after CSS changes rather than relying solely on dev mode.

## Key Rules

- Do not shorten CSS Module hash lengths below 8 characters in production build configs
- Use `:global()` only for targeting third-party library injected class names, never your own
- Pick Tailwind or CSS Modules per project, do not mix on the same elements
- Test CSS in production build (`next build`) not just dev mode — hashes differ
- In monorepos, ensure each package has its own CSS Module hash scope prefix configured
- When debugging CSS collisions, add `[folder]__` prefix to `localIdentName` to make file scope visible
