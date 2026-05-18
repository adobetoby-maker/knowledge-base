# Failure: Turbopack Gotchas in Next.js

## Overview
Turbopack is Next.js's new bundler, available for development (`next dev --turbopack`) and progressively rolling out for production builds. It's significantly faster than Webpack but not a drop-in replacement — Webpack plugins, custom loaders, and some configuration options have no Turbopack equivalent. The safe strategy: use Turbopack for local dev (faster HMR), keep Webpack for production builds until Turbopack stabilizes.

## Webpack Plugins That Don't Work

```js
// next.config.js — webpack() customizations are ignored by Turbopack
module.exports = {
  webpack: (config) => {
    // This ONLY applies to webpack builds, not Turbopack
    config.plugins.push(new MyCustomPlugin())
    config.module.rules.push({ test: /\.svg$/, use: ['@svgr/webpack'] })
    return config
  },
}
```

For Turbopack, use the `experimental.turbo` config:

```js
module.exports = {
  experimental: {
    turbo: {
      rules: {
        '*.svg': {
          loaders: ['@svgr/webpack'],
          as: '*.js',
        },
      },
    },
  },
}
```

Check Turbopack compatibility for each Webpack loader you use: https://nextjs.org/docs/app/api-reference/turbopack

## CSS Handling Differences

CSS import order can differ between Webpack and Turbopack:

```tsx
// Webpack: order determined by import order in the file
// Turbopack: may reorder based on module graph traversal

// BAD — relying on import order for specificity
import styles from './base.module.css'
import override from './override.module.css'  // Webpack: overrides base. Turbopack: might not.

// GOOD — use explicit specificity in CSS
// override.module.css
.button:where(.override) { color: red; }  // higher specificity than base
```

Global CSS import order is especially fragile — move specificity to selectors, not import order.

## CSS Modules Work, But Edge Cases Differ

```tsx
// This works in both:
import styles from './Button.module.css'
<button className={styles.button}>Click</button>

// This may differ:
// Webpack: generated class name is deterministic in production
// Turbopack: may generate different class names
// Solution: never reference generated class names in tests or JS — only use the `styles.` object
```

## Switching Between Dev and Prod

```bash
# Turbopack dev
next dev --turbopack

# Webpack dev (fallback)
next dev

# Production build — Webpack (stable)
next build
```

If you see different behavior in dev vs production:

1. Run `next dev` (Webpack) and `next dev --turbopack` — compare
2. If different, the Turbopack behavior is likely a bug — file an issue
3. Add to `.npmrc` or CI: `TURBOPACK=0` to force Webpack in specific environments

## Known Limitations (as of Next.js 15)

- `next.config.js` `webpack()` function is not called during Turbopack builds
- Some Babel transforms not supported — check `babel-plugin-*` usage
- Module federation not supported
- Custom server (`server.js`) limitations apply
- `@next/bundle-analyzer` doesn't work with Turbopack (webpack-specific)

## Debugging Build Differences

```bash
# Build stats with Webpack
ANALYZE=true next build

# Check if an issue is Turbopack-specific
next build  # if this passes but dev has issues → Turbopack bug
```

If a package breaks with Turbopack, check its GitHub issues for "turbopack" before debugging locally.

## Key Rules
- Turbopack for `next dev` is production-safe in Next.js 15+ — it's the default
- Turbopack for `next build` is in beta — test thoroughly before enabling in production
- Don't migrate `webpack()` customizations to `turbo.rules` until you've verified equivalence
- CSS import order dependency is an anti-pattern in both bundlers — fix the specificity
- Test your CI builds with the same bundler as production (`next build` not `next dev`)
- If Turbopack breaks something: `next dev` (no `--turbopack`) as immediate fallback
