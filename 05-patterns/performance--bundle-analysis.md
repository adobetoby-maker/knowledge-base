# Bundle Analysis — Find What's Making Your JS Large

**When:** Build is slow, Lighthouse shows "Reduce unused JavaScript", or you want to understand what's shipping to users.
**Rule:** Run bundle analysis before blindly removing packages or optimizing. Know what's actually large before fixing it.

## Next.js Bundle Analyzer
```bash
# Install
npm install --save-dev @next/bundle-analyzer

# next.config.ts
import withBundleAnalyzer from '@next/bundle-analyzer'
const withAnalyzer = withBundleAnalyzer({ enabled: process.env.ANALYZE === 'true' })
export default withAnalyzer(nextConfig)

# Run
ANALYZE=true npm run build
# Opens two treemaps in browser: server bundle, client bundle
```

## Reading the Treemap
- **Large boxes** = large packages. These are your targets.
- **Colors** = different files/packages
- **Click to zoom** = see what's inside large packages
- **Focus on client bundle** — server bundle doesn't affect users

## What to Look For
```
react-dom         — expected (~130kb) — don't cut this
next              — expected (~200kb) — don't cut this
@supabase/ssr     — expected (~80kb) if you use Supabase
problematic:
  moment          — 67kb, use date-fns instead
  lodash          — 70kb, import specific functions or go vanilla
  chart.js        — 200kb, try recharts or lazy load it
  three           — 600kb+, MUST be lazy loaded with ssr:false
  large icons libs — import specific icons, not the whole library
```

## Fixing a Large Bundle

### Lazy load large components
```typescript
// Instead of: import { Chart } from 'chart.js'
const Chart = dynamic(() => import('./Chart'), {
  loading: () => <div style={{ height: 300 }}>Loading...</div>
})
```

### Tree-shake icon libraries
```typescript
// WRONG — imports all 5000 icons
import { FaUser, FaHome } from 'react-icons/fa'

// RIGHT — only imports those two icons (react-icons is tree-shakeable)
import { FaUser } from 'react-icons/fa/FaUser'
import { FaHome } from 'react-icons/fa/FaHome'
```

### Replace heavy packages with lighter alternatives
```typescript
// Dates: moment → date-fns (or native Intl)
import { format } from 'date-fns'  // imports only format function
format(new Date(), 'MMM d, yyyy')

// vs:
import moment from 'moment'  // 67kb entire library
moment().format('MMM D, YYYY')
```

### Check if a package is actually used
```bash
# Find all imports of a package
grep -r "from 'lodash'" src/ --include="*.ts" --include="*.tsx"
# If only used in 1-2 places, rewrite those as vanilla JS
```

## Lighthouse JavaScript Metrics
- **First Contentful Paint (FCP)** — how fast something appears
- **Time to Interactive (TTI)** — how fast users can interact
- **Total Blocking Time (TBT)** — how long JS blocks the main thread

Large bundles increase all three. Target: < 200kb of initial JS for a typical page.
