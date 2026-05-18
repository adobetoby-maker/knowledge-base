# Failure: Build Cache Issues

## Overview

Stale build caches cause: code changes not reflecting in production, types that don't update, tests passing locally but failing in CI, and mysterious "works on my machine" bugs. The main caches to know: Next.js `.next/` build output, Turbo/nx remote cache, TypeScript incremental compilation, and node_modules.

## Next.js Stale Build Cache

```bash
# Clear Next.js build cache
rm -rf .next

# Full reset including node_modules
rm -rf .next node_modules/.cache

# Next.js has aggressive caching — if pages look stale in production:
# 1. Check Vercel build cache settings
# 2. Try "Override build cache" in Vercel dashboard
# 3. Or add cache busting to next.config.ts
```

```ts
// next.config.ts — disable cache for debugging
const nextConfig = {
  // Force fresh builds by embedding a timestamp
  generateBuildId: async () => {
    return `build-${Date.now()}`
  },
}
```

## TypeScript Incremental Build Cache

```bash
# tsconfig.json with incremental compilation
{
  "compilerOptions": {
    "incremental": true,
    "tsBuildInfoFile": "./.tsbuildinfo"
  }
}

# If TypeScript errors are confusing or seem wrong:
rm .tsbuildinfo  # Delete incremental cache
npx tsc --noEmit  # Rebuild from scratch
```

## Turbo Cache Problems

```bash
# Turborepo remote/local cache
# Local cache
rm -rf .turbo/

# Force fresh run
npx turbo run build --force

# View what was cached
npx turbo run build --dry-run

# In CI — if remote cache gives wrong results:
npx turbo run build --no-cache
```

## Node Modules Cache

```bash
# When package.json changed but npm install didn't run properly
rm -rf node_modules
npm install

# Or with pnpm
rm -rf node_modules pnpm-lock.yaml
pnpm install

# Verify installed version
cat node_modules/<package>/package.json | grep '"version"'
```

## Vite/Rollup Cache

```bash
# Vite dev cache
rm -rf node_modules/.vite

# Vite build cache
rm -rf dist

# If Vite shows old module despite file changes:
# 1. Check if file is properly imported (not duplicated path case)
# 2. Restart dev server
# 3. Hard reload browser (Cmd+Shift+R)
```

## ESLint Cache

```bash
# ESLint caches results by default
npx eslint . --cache

# If rules changed but lint results look stale:
rm .eslintcache
npx eslint .
```

## CI Cache Debugging

```yaml
# GitHub Actions — skip cache to debug
- uses: actions/cache@v3
  with:
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    # Add this to force rebuild:
    # restore-keys: ''  # Disable fallback
```

```bash
# Check what's actually cached in CI
echo "Cache hit: ${{ steps.cache.outputs.cache-hit }}"

# Force bypass by changing the cache key
key: ${{ runner.os }}-node-v2-${{ hashFiles('**/package-lock.json') }}
#                              ^^^ increment to bust
```

## Next.js Data Cache (App Router)

The App Router has a 4-layer cache that can serve stale data:

```ts
// Force no caching for dynamic data
const res = await fetch(url, { cache: 'no-store' })

// Or revalidate on interval
const res = await fetch(url, { next: { revalidate: 60 } })

// Manual revalidation from route handler
import { revalidatePath, revalidateTag } from 'next/cache'
revalidatePath('/products')
revalidateTag('products-list')
```

## Symptoms and Fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| Old code running in prod | `.next` cache not invalidated | `rm -rf .next` on server or Vercel |
| Type errors that make no sense | Stale `.tsbuildinfo` | `rm .tsbuildinfo` |
| Tests pass locally, fail CI | `node_modules` mismatch | Verify `package-lock.json` is committed |
| Page shows old data | Next.js data cache | `revalidatePath()` or `cache: 'no-store'` |
| Import resolves wrong file | Module resolution cache | Restart dev server |

## Key Rules

- When debugging mysterious issues, cache invalidation is a primary suspect — always try clearing before diving deep.
- In CI, use the file hash (`hashFiles('**/package-lock.json')`) as the cache key to invalidate when dependencies change.
- Increment cache key version suffixes when changing cache configuration — old caches are incompatible.
- Next.js App Router has 4 caches (Request Memoization, Data Cache, Full Route Cache, Router Cache) — understand which layer is stale.
- `revalidatePath` and `revalidateTag` are the correct way to invalidate Next.js data cache in route handlers and Server Actions.
