# Vercel Deployment Errors

## 1. Build Fails: Module Not Found

**Symptom:** `Module not found: Can't resolve '@/components/SomeComponent'`

**Cause 1:** File exists locally but wasn't committed to git.
**Cause 2:** Case sensitivity mismatch — macOS is case-insensitive, Linux is not. `SomeComponent.tsx` and `somecomponent.tsx` are the same on Mac, different on Vercel (Linux).

**Fix:**
```bash
# Check if the file is tracked by git
git status
git ls-files | grep SomeComponent

# Fix case sensitivity issues
git mv SomeComponent.tsx someComponent.tsx
# If that fails (same name after normalization):
git rm --cached SomeComponent.tsx
git add someComponent.tsx
```

## 2. Build Fails: Type Error or Lint Error

**Symptom:** Build passes locally, fails on Vercel with TypeScript errors.

**Cause:** Local TypeScript version or tsconfig differs from what Vercel uses. Or `strict` mode is off locally but on in CI.

**Fix:**
```bash
# Run the same check Vercel runs
npm run build
# or
npx tsc --noEmit
npm run lint
```

Always run `tsc --noEmit` locally before pushing. Don't use `// @ts-ignore` to bypass errors — fix them.

## 3. Function Timeout (10s / 60s)

**Symptom:** Serverless function returns 504 Gateway Timeout.

**Cause:** Route Handler or Server Action exceeds the function timeout (10s on Hobby, 60s on Pro).

**Fix:**
```typescript
// For long operations, use streaming or background jobs
// In the route handler:
export const maxDuration = 60  // seconds, max allowed by your plan

// For operations that truly need > 60s, use background jobs
// (Vercel Cron, Supabase Edge Functions, or Cloudflare Workers)
```

For large data operations: paginate, stream, or split into chunks.

## 4. Edge Runtime Compatibility Error

**Symptom:** `The edge runtime does not support Node.js 'fs' module`

**Cause:** A Route Handler or middleware uses a Node.js built-in that's not available in the Edge runtime.

**Fix:**
```typescript
// Add to the route file to force Node.js runtime
export const runtime = 'nodejs'

// Or remove 'export const runtime = "edge"' if present
```

Edge runtime restrictions: no `fs`, `child_process`, `crypto` (Node.js), `net`. Available: `fetch`, Web Crypto, Web APIs.

## 5. Deployment Environment Variable Missing

**Symptom:** Works in development, fails in production with "undefined" or "Cannot read property of undefined".

**Cause:** Environment variable set in `.env.local` but not in Vercel project settings.

**Fix:**
1. Go to Vercel dashboard → Project → Settings → Environment Variables
2. Add the missing variable for the Production environment
3. Redeploy (env vars baked at build time for `NEXT_PUBLIC_*`)

**Note:** `NEXT_PUBLIC_*` variables are embedded at BUILD time. Changing them in Vercel settings requires a new deployment — updating the variable alone doesn't affect the running deployment.

## 6. Image Optimization Fails on Cloudflare Workers

**Symptom:** `next/image` optimization throws an error on `@opennextjs/cloudflare` builds.

**Cause:** Sharp (the image optimizer) requires Node.js APIs not available in the Cloudflare Workers runtime.

**Fix:**
```typescript
// In the page/component that uses next/image:
export const runtime = 'nodejs'
```

Or use pre-optimized images served from R2 or Cloudflare Images service, bypassing `next/image` optimization entirely.

## 7. 404 on Dynamic Routes After Static Export

**Symptom:** Dynamic route pages return 404 on Vercel, work locally.

**Cause:** Using `output: 'export'` in `next.config.ts` with dynamic routes that need `generateStaticParams`.

**Fix:**
```typescript
// next.config.ts — if using static export
// All dynamic routes MUST have generateStaticParams
export function generateStaticParams() {
  return articles.map(a => ({ slug: a.slug }))
}
// Missing generateStaticParams for a dynamic route → 404 after static export
```

For dynamic routes that can't be pre-generated, remove `output: 'export'` and use Vercel's server rendering.

## 8. CORS on API Routes

**Symptom:** Browser gets CORS error when calling your own API route from a different domain.

**Cause:** Cross-origin requests need CORS headers. Next.js doesn't add them by default.

**Fix:**
```typescript
// app/api/public/route.ts
export async function GET() {
  return NextResponse.json(data, {
    headers: {
      'Access-Control-Allow-Origin': '*',  // or specific domain
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    },
  })
}

export async function OPTIONS() {
  return new Response(null, {
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  })
}
```

Only add CORS headers for routes meant to be called from other domains (public APIs). Don't add them to auth or admin routes.
