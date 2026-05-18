# Stale Next.js Build Cache Serving Wrong Content

Next.js build cache (`.next/cache`) is an optimization that can serve the wrong content when the cache contains artifacts built under different conditions. This is a silent failure: the build succeeds, the app starts, but users see old content, wrong environment values, or mismatched code.

## How the Build Cache Gets Poisoned

The `.next/cache` directory stores compiled pages, static assets, and incremental static regeneration (ISR) artifacts. Next.js uses content hashing and dependency tracking to invalidate cache entries, but this tracking is imperfect. Common poisoning scenarios:

**Environment variable changes**: The build was cached with `NEXT_PUBLIC_API_URL=https://staging-api.example.com`. You change it to production. Next.js may reuse cached bundles that have the staging URL baked in, because it doesn't always recognize env var changes as invalidating cached pages.

**npm package updates without cache invalidation**: A dependency is updated. The cached webpack/SWC outputs were compiled against the old version. Some (but not all) affected files get recompiled; the rest come from cache and may be inconsistent.

**Corrupted partial build**: A build was interrupted mid-way. The cache contains a mix of old and new artifacts. The next build picks up the partial cache and produces a hybrid.

**Stale ISR cache**: Pages with `revalidate` were cached with old data. A content change is made but the ISR cache holds the old version past its revalidation window — or the revalidation path is broken and it never updates.

## The Fix: Delete .next Before Building

When you change environment variables, upgrade Next.js, or experience unexplained content inconsistencies:

```bash
rm -rf .next && npm run build
```

`next build --no-lint`, `next build --no-cache`, and similar flags do not clear the build cache. The only reliable way to start clean is to delete the `.next` directory before building.

In CI, this is handled automatically because each build runs in a clean environment. In local development, the `.next` directory persists between builds, which is where most cache poisoning occurs.

## Vercel Build Cache Clearing Procedure

Vercel maintains its own build cache separate from the `.next/cache` in the repository. When a deployment serves wrong content after an env var change or dependency update:

1. Go to the project in the Vercel dashboard
2. **Deployments** → select the affected deployment
3. Click **Redeploy** → check **"Clear build cache and redeploy"**

Or via CLI:
```bash
vercel deploy --force  # Forces a fresh build, bypasses Vercel build cache
```

The `--force` flag is the Vercel CLI equivalent of clearing `.next` locally.

## Environment Variable Changes Require Cache Busting

`NEXT_PUBLIC_*` variables are inlined into client bundles at build time. If you change one and redeploy without clearing the build cache, the old inlined value may be served from cache. This is the most insidious version of cache poisoning because it looks like a code change that didn't deploy.

Rule: whenever you add, change, or remove a `NEXT_PUBLIC_*` variable, clear the build cache as part of the deployment.

## Diagnosing Cache Poisoning

Signs you have a stale cache:
- Build output says "Using cached..." for files you know changed
- Console logs in the browser show old values for `NEXT_PUBLIC_*` variables
- Deployed pages show content that was previously correct but should have changed
- TypeScript errors in build that reference types that no longer exist (cached compilation)

Check `/_next/static/chunks/*.js` in the browser network tab — look for old string values that should have changed.

## Key Rules

- `rm -rf .next` before building after any env var change — other build flags don't clear the cache
- In Vercel, use "Clear build cache and redeploy" after env var changes or unexpected content issues
- `NEXT_PUBLIC_*` variables are baked into bundles at build time; cache must be cleared when they change
- ISR cache is separate — use `res.revalidate(path)` or `next/cache` revalidation to bust it on-demand
- `vercel deploy --force` bypasses Vercel's build cache; use when deploying after dependency or env changes
- In CI, add `rm -rf .next` as a pre-build step if build caching is enabled
