# Failure: Large Bundle Size

## What It Is

JavaScript bundle size directly affects Time to Interactive. Every KB of JS must be downloaded, parsed, and executed before the page becomes interactive. A 1MB bundle on a mobile 3G connection takes 10+ seconds to parse. The goal: keep the initial bundle under 200KB gzipped.

## Detection

```bash
# Next.js bundle analysis
npm install @next/bundle-analyzer

# next.config.ts
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
})
module.exports = withBundleAnalyzer({})

# Run
ANALYZE=true npm run build
```

The treemap shows which packages dominate bundle size.

## Common Offenders

| Package | Size | Fix |
|---|---|---|
| `moment.js` | 232KB | Replace with `date-fns` (tree-shakeable) or `dayjs` |
| `lodash` | 531KB | Use `lodash-es` with named imports |
| `recharts` | 350KB | Lazy-load chart components |
| `monaco-editor` | 5MB | `dynamic(() => import(...))` |
| `@faker-js/faker` | 2MB | Dev-only — don't import in production |
| `three.js` | 600KB | Load only on pages that need it |
| Icon libraries | Variable | Import individual icons, not full set |

## Fix 1: Lazy Loading

```tsx
import dynamic from 'next/dynamic'

// Don't bundle Monaco until it's needed
const MonacoEditor = dynamic(() => import('@monaco-editor/react'), {
  ssr: false,
  loading: () => <div className="h-64 bg-gray-100 animate-pulse" />,
})

// Don't bundle chart library until the chart section renders
const RevenueChart = dynamic(() => import('./charts/RevenueChart'), {
  ssr: false,
})
```

## Fix 2: Tree-Shake lodash

```ts
// BAD: Imports all of lodash (531KB)
import _ from 'lodash'
const sorted = _.sortBy(items, 'name')

// GOOD: Import only what you use (a few KB)
import { sortBy } from 'lodash-es'
const sorted = sortBy(items, 'name')
```

Or use native equivalents:
```ts
// Instead of _.groupBy
const grouped = items.reduce((acc, item) => {
  ;(acc[item.category] ??= []).push(item)
  return acc
}, {} as Record<string, typeof items>)
```

## Fix 3: Replace moment.js

```ts
// moment.js: 232KB
import moment from 'moment'
moment().format('MMMM DD, YYYY')

// date-fns: tree-shakeable, ~30KB for typical usage
import { format } from 'date-fns'
format(new Date(), 'MMMM dd, yyyy')

// dayjs: 2KB base, plugins on demand
import dayjs from 'dayjs'
dayjs().format('MMMM DD, YYYY')
```

## Fix 4: Icon Imports

```ts
// BAD: Imports entire icon library
import * as Icons from 'lucide-react'
const { Home, Settings, User } = Icons

// GOOD: Named imports (tree-shakeable)
import { Home, Settings, User } from 'lucide-react'
```

## Fix 5: Split Vendor Chunks

```ts
// next.config.ts
module.exports = {
  webpack: (config) => {
    config.optimization.splitChunks = {
      chunks: 'all',
      cacheGroups: {
        defaultVendors: {
          test: /[\\/]node_modules[\\/]/,
          priority: -10,
          reuseExistingChunk: true,
        },
      },
    }
    return config
  },
}
```

## Measuring Progress

```bash
# Before and after comparison
npm run build 2>&1 | grep "First Load JS"
```

```
Route (app)                              Size     First Load JS
┌ ○ /                                  5.23 kB        92.5 kB   ← Target: < 100KB
├ ○ /dashboard                         18.2 kB         282 kB   ← Too large
```

## Key Rules

- `ANALYZE=true npm run build` before shipping any new dependency — check the impact.
- Lazy-load anything >50KB that isn't needed on first render.
- `date-fns` over `moment.js`, `lodash-es` over `lodash` — non-tree-shakeable libraries are bundle time bombs.
- Check `First Load JS` per route in Next.js build output — route bundles should stay under 100KB gzipped.
