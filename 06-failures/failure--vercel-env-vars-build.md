# Failure: Vercel — Environment Variables Missing at Build Time

**Symptom:** `Error: supabaseUrl is required` or similar crashes during `vercel build` / `next build` on Vercel, but works fine locally.

**Cause:** Next.js evaluates module-level code during build. Env vars aren't available at build time in Vercel (they're runtime-only unless explicitly added as Build Environment Variables in the Vercel dashboard).

## Three Fixes (pick the right one)

### Fix 1 — Lazy Initialization (best for SDK clients)
```typescript
// ❌ Module-level init — crashes at build
import { createClient } from '@supabase/supabase-js'
export const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!)

// ✅ Lazy init — defers until first call (runtime)
import { createClient, SupabaseClient } from '@supabase/supabase-js'
let _client: SupabaseClient | null = null
export function getSupabase() {
  if (!_client) {
    _client = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!)
  }
  return _client
}
```

### Fix 2 — force-dynamic (best for single route/page)
```typescript
// Add to the top of the page or route handler
export const dynamic = 'force-dynamic'
// This tells Next.js: don't prerender this route, skip build-time evaluation
// Doesn't fix module-level code in imports — combine with lazy init if needed
```

### Fix 3 — Add as Build Environment Variable (best when NEXT_PUBLIC_ vars are needed at build)
In Vercel dashboard → Project Settings → Environment Variables:
- Add the variable
- Check "Available during build" 
This makes it available at build time, but only use for public vars (NEXT_PUBLIC_*).
Never expose private keys as build variables.

## Which Fix for Which Situation
```
Module-level client init (Supabase, Stripe, etc.) → Fix 1 (lazy init)
Single API route crashes → Fix 2 (force-dynamic)
NEXT_PUBLIC_ var needed for static rendering → Fix 3 (build var)
Server-only private key → Fix 1 always (never expose to build)
```

## Diagnostic — Find the Source
```bash
# Run build locally to see the same error
npm run build 2>&1 | grep -A5 "Error\|error"

# Find all module-level env var access
grep -rn "process\.env\." --include="*.ts" --include="*.tsx" . | grep -v "function\|=>\|const.*=.*(" | head -20
```

## Why force-dynamic Alone Doesn't Fix Module-Level Code
`force-dynamic` prevents the page from being statically rendered, but it doesn't prevent imports from being evaluated. When `page.tsx` imports `lib/supabase/admin.ts` and that module has `createClient(process.env.URL!)` at module level, that code runs when the module is first imported — which happens during build regardless of `force-dynamic`.

Lazy init is the only complete fix for module-level initialization.
