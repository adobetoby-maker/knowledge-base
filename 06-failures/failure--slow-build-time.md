# Failure: Slow Next.js Build Time

Next.js build time grows non-linearly with codebase size when common patterns are used carelessly. A build that took 30 seconds at project start can grow to 5+ minutes without any single obvious cause. The culprit is usually excessive module graph resolution, not compute-intensive operations.

## Barrel File Imports

Barrel files (`index.ts` that re-exports everything from a directory) are convenient but destructive for build performance. When you import one named export from a barrel, webpack/turbopack must parse and potentially bundle every file the barrel re-exports — even those you don't use.

```ts
// BAD — importing from a barrel forces loading all 200 icon files
import { IconArrow } from '../components/icons'; // icons/index.ts exports all icons

// GOOD — direct import loads only this one file
import { IconArrow } from '../components/icons/IconArrow';
```

At scale: a barrel with 200 re-exports that 50 components each import one item from means the bundler processes 200 files × 50 times instead of 1 file × 50 times. This is the single most common cause of mysteriously slow builds in large React projects.

The fix for your own code: delete barrel `index.ts` files (or keep them only for public API surfaces, not internal directories). The fix for third-party packages: use `modularizeImports`.

## modularizeImports for Icon Packages

Icon packages (lucide-react, react-icons, @heroicons/react) export thousands of icons from a single entry point. Without configuration, importing a single icon loads the entire package.

```js
// next.config.js
const nextConfig = {
  modularizeImports: {
    'lucide-react': {
      transform: 'lucide-react/dist/esm/icons/{{kebabCase member}}',
    },
    '@heroicons/react/24/outline': {
      transform: '@heroicons/react/24/outline/{{member}}',
    },
  },
};
```

This rewrites import statements at compile time from the barrel import to the direct file path. Zero code changes needed — the transformation is transparent.

Check bundle size before and after with `ANALYZE=true npm run build` (using `@next/bundle-analyzer`) to confirm the reduction.

## Turbopack for Development

Turbopack is Next.js's Rust-based bundler, available in dev mode. It uses incremental compilation with persistent cache — only files that changed are re-bundled. For large codebases this reduces dev server startup from 30+ seconds to under 2 seconds, and HMR from 2–5s to under 200ms.

```bash
next dev --turbopack
```

Turbopack is stable for development as of Next.js 14.1. It is not yet the default for `next build` (production builds still use webpack by default as of early 2026 — check the Next.js changelog for current status).

Do not use Turbopack for production builds until it graduates from beta for that use case.

## next build --debug

The `--debug` flag outputs a profiling trace that identifies which compilation steps are slowest:

```bash
NEXT_TELEMETRY_DISABLED=1 next build --debug
```

Look for:
- Files that take unusually long to compile (may indicate a complex type or a deeply nested import chain)
- The number of modules processed (high counts indicate barrel file problems)
- Slow TypeScript type checking (consider `transpileOnly: true` during builds and run `tsc --noEmit` separately)

## TypeScript Type Checking at Build Time

`next build` runs TypeScript type checking by default. On large codebases this can account for 40–60% of build time. Options:

1. Keep it — type errors caught in CI are worth the time.
2. Disable build-time checking and run `tsc --noEmit` as a separate CI step (allows parallelization).
3. Use `swc` or `transpileOnly` mode to skip type checking in the bundler — but you must have another step that actually checks types.

Never disable type checking entirely — this trades build speed for silent type errors in production.

## Key Rules

- Delete internal barrel files that re-export everything from a directory; use direct imports.
- Configure `modularizeImports` for any icon or utility package with a large barrel export.
- Use `next dev --turbopack` for all development; it has near-zero overhead for incremental rebuilds.
- Run `next build --debug` to profile before optimizing — identify the actual slow step before changing code.
- Move TypeScript type checking to a parallel CI job if build time matters more than fast CI feedback.
- Audit new dependencies: adding a package that uses deep barrel exports will immediately inflate build time.
