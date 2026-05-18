# Failure: Oversized Webpack / Next.js Chunks

## Overview
A JavaScript chunk is a bundle file sent to the browser. When a page's JavaScript chunk is too large, users pay the cost on every page load: download time, parse time, and execution time — even for code that is only needed much later in the user flow. The effect is worst on mobile devices and slow connections, where a 1MB bundle can block interactivity for 5+ seconds. The goal is for each chunk to be under 250KB gzipped and to load only what the current page needs.

## How Chunks Become Too Large

**All imports in one bundle:**
```typescript
// pages/dashboard/page.tsx — everything imported at module level
import { BarChart, LineChart, PieChart, HeatMap } from "recharts"; // 300KB
import { DataGrid } from "@mui/x-data-grid"; // 200KB
import { RichTextEditor } from "@uiw/react-textarea-code-editor"; // 150KB
// ^ All downloaded even if user never opens a chart or table
```

**Large dependencies imported everywhere:**
```typescript
// Every file imports lodash entirely
import _ from "lodash"; // 72KB gzipped
// vs
import debounce from "lodash/debounce"; // 2KB
```

## Analyzing Bundle Size

```bash
# Next.js: install analyzer
npm install --save-dev @next/bundle-analyzer

# next.config.ts
import withBundleAnalyzer from "@next/bundle-analyzer";
export default withBundleAnalyzer({ enabled: process.env.ANALYZE === "true" })({
  /* your next config */
});

# Run analysis
ANALYZE=true next build
# Opens two HTML reports: client bundle and server bundle
# Look for: large vendor chunks, duplicated modules, unexpectedly large pages
```

## Dynamic Imports — The Primary Fix

`dynamic()` in Next.js (wraps React's `lazy()` + `Suspense`) defers loading until the component is needed:

```typescript
import dynamic from "next/dynamic";

// Wrong: recharts included in initial bundle
import { BarChart } from "recharts";

// Right: recharts loaded only when AnalyticsDashboard renders
const AnalyticsDashboard = dynamic(() => import("./AnalyticsDashboard"), {
  loading: () => <Skeleton className="h-64 w-full" />,
  ssr: false, // disable SSR for browser-only libraries (optional)
});

// Usage
export default function DashboardPage() {
  return (
    <div>
      <Header />
      <AnalyticsDashboard /> {/* recharts only downloaded when this renders */}
    </div>
  );
}
```

## Vendor Chunk Splitting

Separate large, stable dependencies into their own chunks so they are cached independently:

```typescript
// next.config.ts
export default {
  webpack(config) {
    config.optimization.splitChunks = {
      chunks: "all",
      cacheGroups: {
        react: {
          test: /[\\/]node_modules[\\/](react|react-dom)[\\/]/,
          name: "react-vendor",
          chunks: "all",
          priority: 30,
        },
        charts: {
          test: /[\\/]node_modules[\\/](recharts|d3)[\\/]/,
          name: "charts-vendor",
          chunks: "async",
          priority: 20,
        },
        ui: {
          test: /[\\/]node_modules[\\/](@radix-ui|@headlessui)[\\/]/,
          name: "ui-vendor",
          chunks: "all",
          priority: 10,
        },
      },
    };
    return config;
  },
};
```

Stable vendor chunks are cached by the browser across deploys — a user who visited yesterday only downloads your changed code, not the entire React library again.

## Tree-Shaking: Named Imports

Bundlers eliminate unused code through tree-shaking — but only when using named imports:

```typescript
// Wrong: imports entire lodash, tree-shaking doesn't work for CJS modules
import _ from "lodash";
const debouncedFn = _.debounce(fn, 300);

// Right: named import from lodash-es (ESM, tree-shakeable)
import { debounce } from "lodash-es";
const debouncedFn = debounce(fn, 300);

// Or direct path import (works with CJS lodash)
import debounce from "lodash/debounce";
```

## Target Chunk Sizes

| Chunk type | Target size (gzipped) |
|---|---|
| Per-page JS | < 100KB |
| Shared app JS | < 150KB |
| Vendor (React, etc.) | < 200KB |
| Feature-specific (charts, editor) | < 250KB |
| Any single chunk | < 250KB |

Pages that exceed these targets need dynamic imports applied.

## Key Rules
- Analyze bundle with `ANALYZE=true next build` before every major release
- Large libraries (charts, rich text editors, data grids, maps) → always `dynamic()` with a loading skeleton
- Named imports, not default object imports (use `lodash-es` not `lodash`)
- Vendor splitting separates stable dependencies from frequently changing app code
- `ssr: false` on dynamic imports for browser-only libraries (avoids SSR hydration mismatches)
- Monitor chunk sizes in CI: fail the build if any chunk exceeds 500KB gzipped
- `import "server-only"` prevents large server-side libraries from leaking into client bundles
