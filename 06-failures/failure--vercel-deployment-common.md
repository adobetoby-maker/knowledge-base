# Vercel Deployment — Common Failures and Fixes

## Build Error: Module Not Found

**Symptom:** Build fails with `Cannot find module '@/components/X'` or similar

**Cause 1:** Case sensitivity. Local macOS filesystem is case-insensitive; Linux (Vercel) is case-sensitive. `import Button from '@/components/button'` fails if the file is `Button.tsx`.

**Fix:** Always match import paths exactly to filenames. Check: `find components -name "*.tsx" | sort` to see actual casing.

**Cause 2:** Missing `paths` alias in `tsconfig.json`.

**Fix:** Ensure `@/*` alias is configured:
```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./*"]
    }
  }
}
```

## Build Error: Environment Variable Missing

**Symptom:** Build fails with `NEXT_PUBLIC_SUPABASE_URL is not defined` or similar undefined env var

**Cause:** Env var not added to Vercel project settings, or added under wrong environment (Preview only, not Production).

**Fix:**
1. Vercel dashboard → Project → Settings → Environment Variables
2. Add the variable for Production + Preview + Development
3. Redeploy — env vars are baked at build time

**Critical:** `NEXT_PUBLIC_*` variables are embedded into the JavaScript bundle at build time. Changing them requires a new build — runtime updates do NOT affect them.

## Build Error: Type Error

**Symptom:** Build fails with TypeScript type errors that don't appear locally

**Cause 1:** Vercel runs `tsc --noEmit` (or equivalent) during build; local may have different tsconfig strictness.

**Cause 2:** Different TypeScript version on CI vs local.

**Fix:** Run `npx tsc --noEmit` locally before deploying. Fix every error before pushing.

**Common type error in Next.js 15+:** `params` is `Promise<{ slug: string }>` not `{ slug: string }`:
```typescript
// Wrong (Next.js 13/14):
export default function Page({ params }: { params: { slug: string } }) {

// Right (Next.js 15+):
export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
```

## Runtime Error: Supabase Client Initialization

**Symptom:** `Error: @supabase/ssr: Your project's URL and API key are required` or similar

**Cause:** Supabase client instantiated at module level (outside function body), running during static analysis at build time when env vars may not be present.

**Fix:** Use the proxy/lazy initialization pattern:
```typescript
// Wrong — runs at module load time
const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, ...)

// Right — lazy initialization via function
let _supabase: ReturnType<typeof createClient> | null = null
export function getSupabase() {
  if (!_supabase) _supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, ...)
  return _supabase
}
```

## Runtime Error: API Route 500 in Production Only

**Symptom:** API route works locally, returns 500 in production with no useful error in Vercel logs

**Cause:** Missing env var, wrong env var value, or network restriction (Vercel can't reach internal services by IP).

**Diagnosis:**
1. Vercel dashboard → Deployments → [deployment] → Functions → [function] → Logs
2. Add `console.error(error)` to catch blocks temporarily
3. Check: is the env var in Vercel settings? Is the service reachable from Vercel (not just localhost)?

## Edge Runtime Incompatibility

**Symptom:** `The edge runtime does not support Node.js 'X' module` or crypto/buffer errors

**Cause:** A file in the edge runtime path imports a Node.js-only module.

**Fix:** Either switch the route to Node.js runtime:
```typescript
export const runtime = 'nodejs'
```

Or replace the Node.js module with a Web API equivalent (e.g., `crypto.subtle` instead of Node `crypto`).

## Function Timeout

**Symptom:** API route returns 504 Gateway Timeout in production

**Cause:** Vercel Hobby plan: 10s function timeout. Pro plan: 60s. Enterprise: 900s.

**Fix options:**
1. Optimize the slow operation
2. Use streaming responses (stream starts immediately, timeout based on time to first byte)
3. Move to background job with a queue (respond immediately, process async)
4. Upgrade plan if legitimately needed

## Image Optimization 400

**Symptom:** Next.js Image component returns 400 or shows broken image

**Cause:** Image `src` domain not in `next.config.js` `images.remotePatterns`.

**Fix:**
```javascript
// next.config.js
module.exports = {
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'example.com' },
      { protocol: 'https', hostname: '*.supabase.co' },
    ]
  }
}
```
