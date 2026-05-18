# Stack Bundle: Vite + React + TypeScript

## Overview
Vite replaces webpack as the dev-server and bundler for React apps, using native ES modules for near-instant
hot module replacement. The production build still uses Rollup under the hood. Understanding the boundary
between Vite's dev-time transform and Rollup's production bundling prevents configuration surprises.

## Implementation

### vite.config.ts Setup
```ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [
    react(),               // Babel-based Fast Refresh + JSX transform
    // OR: react({ jsxRuntime: 'automatic' }) to skip manual React import
  ],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),  // enables import from '@/components/...'
    },
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          // Split vendor bundles to improve caching
          vendor: ['react', 'react-dom'],
          router: ['react-router-dom'],
          // Large UI libraries get their own chunk
          ui: ['@radix-ui/react-dialog', '@radix-ui/react-dropdown-menu'],
        },
      },
    },
    sourcemap: true,      // always enable for production error tracking
    chunkSizeWarningLimit: 600,  // kB — warn if any chunk exceeds this
  },
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:3001',  // proxy to backend dev server
        changeOrigin: true,
      },
    },
  },
});
```

### TypeScript Path Aliases
```json
// tsconfig.json — must match vite.config.ts alias
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  }
}
```
Both vite.config.ts and tsconfig.json must define the same alias or TypeScript will show errors
while Vite compiles successfully — they are independent resolution systems.

### Environment Variables (VITE_ Prefix)
```
.env                    # loaded always
.env.local              # loaded always, gitignored
.env.development        # loaded in `vite dev`
.env.production         # loaded in `vite build`
```
```ts
// Only VITE_ prefixed vars are exposed to client code
const apiUrl = import.meta.env.VITE_API_URL;    // ✓ accessible in browser
const secret = import.meta.env.SECRET_KEY;       // ✗ never exposed, undefined in browser

// Type safety for env vars
/// <reference types="vite/client" />
interface ImportMetaEnv {
  readonly VITE_API_URL: string;
  readonly VITE_SUPABASE_URL: string;
}
```

### Build Optimization
```ts
// manualChunks function form — dynamic grouping
manualChunks(id) {
  if (id.includes('node_modules')) {
    // Group all node_modules into a single vendor chunk
    return 'vendor';
  }
  // Or group by package name for finer control
  if (id.includes('node_modules/react')) return 'react-vendor';
  if (id.includes('node_modules/@radix-ui')) return 'ui-vendor';
}
```
```bash
vite build --mode staging    # uses .env.staging
npx vite-bundle-visualizer   # visual treemap of bundle contents — essential for debugging large bundles
```

### Preview Mode for Production Testing
```bash
vite build && vite preview   # serves production build on localhost:4173
```
Preview mode serves the built files via a local HTTP server. Always test the preview build before
deploying — some issues only appear in the production build (missing env vars, tree-shaking removing
code that looks unused, missing dynamic imports).

### HMR vs Full Reload
```
HMR (Hot Module Replacement): component state preserved, only the changed module is re-evaluated
  → Works for: React component changes, CSS changes, JSON imports

Full reload: entire page reloads
  → Triggered by: changes to non-HMR modules (vite.config.ts itself), changes to modules
    that have side effects outside component trees, changes to tsconfig.json
```
If HMR breaks and triggers full reloads constantly, check for circular imports (`madge` or
`vite-plugin-circular-dependency` will surface these).

## Key Rules
- `VITE_` prefix is mandatory for any env var used in client code — no exceptions, no workarounds
- Path aliases must be declared in both `vite.config.ts` and `tsconfig.json`
- Use `manualChunks` to prevent vendor code from being bundled with app code — vendor changes rarely, enabling long-term caching
- `vite preview` is not a production server; use nginx/Caddy/static hosting for production
- Enable `sourcemap: true` in build config — without it, production error stack traces are unreadable
- Avoid importing large libraries at module level if only needed in one route — use dynamic `import()` for code splitting
- `@vitejs/plugin-react` uses Babel by default; swap to `@vitejs/plugin-react-swc` for faster builds in large projects
