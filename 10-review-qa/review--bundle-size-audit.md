# Review: Bundle Size Audit

## Overview
Bundle size directly impacts Time to Interactive — every extra kilobyte of JavaScript the browser must download, parse, and execute delays when your app becomes usable. The problem is that size creeps: each dependency seems reasonable individually, but together they bloat the initial load. Regular bundle audits catch regressions before they compound.

## Implementation / Key Points

### Analyzing the Bundle

**Next.js:**
```bash
# Install
npm install --save-dev @next/bundle-analyzer

# next.config.ts
import bundleAnalyzer from '@next/bundle-analyzer';
const withBundleAnalyzer = bundleAnalyzer({ enabled: process.env.ANALYZE === 'true' });
export default withBundleAnalyzer({});

# Run
ANALYZE=true npm run build
# Opens treemap in browser — largest rectangles = largest chunks
```

**Vite:**
```bash
npm install --save-dev rollup-plugin-visualizer
# Generates stats.html with treemap
```

### Reading the Treemap
- Each rectangle = a module, sized by its contribution to the bundle
- Look for: unexpectedly large packages, duplicated modules (lodash appearing twice in different chunks), entire libraries pulled in for one function

### Tree-Shaking Verification
```typescript
// Bad: imports entire lodash (~70KB gzipped)
import _ from 'lodash';
const result = _.debounce(fn, 300);

// Good: named import, tree-shakeable if using lodash-es
import { debounce } from 'lodash-es';

// Best: use browser-native where available
function debounce(fn: () => void, delay: number) {
  let timeout: ReturnType<typeof setTimeout>;
  return () => { clearTimeout(timeout); timeout = setTimeout(fn, delay); };
}
```

Common tree-shaking failures:
- `import moment from 'moment'` — moment is not tree-shakeable, use `date-fns`
- `import * as Icons from 'react-icons/ai'` — imports all icons, import individual ones
- `import { something } from 'a-cjs-library'` — CommonJS modules can't be tree-shaken

### Code Splitting with dynamic()
```typescript
// Bad: heavy chart library loaded upfront on every page
import { Chart } from 'chart.js';

// Good: loaded only when needed
const Chart = dynamic(() => import('./ChartComponent'), {
  loading: () => <Skeleton />,
  ssr: false,  // don't include in server bundle if client-only
});
```
Rules for `dynamic()`:
- Components below the fold on first paint
- Heavy libraries used on specific pages/tabs only
- Code paths triggered by user action (modals, drawers, tooltips)

### Server-Only Code Leaking to Client
```typescript
// Bad: crypto and fs are Node-only, crash in browser
import { createHash } from 'crypto';  // in a shared util file

// Good: use 'server-only' package to fail at build time if imported client-side
import 'server-only';
```
Check the bundle for: database drivers, environment variable access without `NEXT_PUBLIC_`, Node built-ins.

### Size Targets (gzipped)
| Bundle | Target |
|---|---|
| Initial JS (above fold) | < 100KB |
| Total initial JS | < 250KB |
| Per-route JS | < 50KB |
| Any single chunk | < 150KB |

### Measurement
```bash
# Always measure gzipped size, not raw
du -sh .next/static/chunks/*.js  # raw
gzip -k .next/static/chunks/main-*.js && du -sh .next/static/chunks/main-*.js.gz  # gzipped

# Or use bundlemon for CI enforcement
npx bundlemon
```

### Audit Checklist
- [ ] Run bundle analyzer and identify top 10 largest chunks
- [ ] Check for duplicate packages (lodash + lodash-es, moment + date-fns)
- [ ] Verify heavy libraries use tree-shakeable imports
- [ ] `moment.js` replaced with `date-fns` (moment is 72KB gzipped)
- [ ] Below-fold components use `dynamic()` import
- [ ] Server-only modules not present in client bundle
- [ ] Measure gzipped size, not raw size

## Key Rules
- Always measure gzipped size — raw size overstates impact by 3-5x
- Tree-shaking only works with ESM (ES modules) — CommonJS libraries can't be shaken
- `moment` should never appear in a modern bundle — replace with `date-fns` or `Intl`
- Every heavy component used on one page or behind a user action should be dynamically imported
- Server-only code leaking to the client is both a security and bundle size issue
- Bundle size audit belongs in CI with a budget that fails the build on regression
