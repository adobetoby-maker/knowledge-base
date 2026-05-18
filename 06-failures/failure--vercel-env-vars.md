# Vercel Environment Variable Failures

## The Most Common Env Var Mistakes

### 1. NEXT_PUBLIC_ Var Not Available at Build Time

**Symptom:** `process.env.NEXT_PUBLIC_SUPABASE_URL` is `undefined` in the browser, even though it's set in Vercel.

**Cause:** `NEXT_PUBLIC_` vars are embedded into the JavaScript bundle AT BUILD TIME. If the var wasn't present when `npm run build` ran, it won't be in the bundle.

**Fix:** 
1. Add the var in Vercel → Project → Settings → Environment Variables
2. **Redeploy** — just adding the var doesn't help existing deployments
3. Verify with a fresh build

**Test:** In a Server Component, `console.log(process.env.NEXT_PUBLIC_SUPABASE_URL)` will show the value server-side even without rebuilding. But `process.env.NEXT_PUBLIC_SUPABASE_URL` in client JavaScript won't see it until a new build.

### 2. Server Var Accessible in Browser (Security Issue)

**Symptom:** No error, but sensitive data is exposed in the browser bundle.

**Cause:** A var without `NEXT_PUBLIC_` was added to `next.config.js` `env` section or similar.

```typescript
// next.config.js — WRONG: this makes server vars available client-side
const config = {
  env: {
    SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,  // EXPOSED
  }
}
```

**Fix:** Never put server-only secrets in `next.config.js` `env`. Leave them as plain `process.env.VARIABLE_NAME` — they'll only be available server-side automatically.

### 3. Missing Var Causes Silent Undefined Error

**Symptom:** Page renders blank or a specific feature silently fails. No error logged.

**Cause:** Code accesses `process.env.SOME_VAR` which is `undefined`, then passes it to a library that doesn't error on undefined but silently does nothing.

```typescript
// Silent failure — Anthropic client initialized with undefined key
const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY })
// If ANTHROPIC_API_KEY is undefined, first API call fails with auth error
// But the error may be caught somewhere upstream and silently swallowed
```

**Fix:** Validate env vars at startup (see `principle--fail-fast.md`). Throw early with a clear message.

### 4. Preview vs Production Var Mismatch

**Symptom:** Works in development and preview deployments, fails in production (or vice versa).

**Cause:** Vars set for "Preview" environment in Vercel don't apply to "Production" and vice versa.

**Fix:**
- Vercel allows setting vars for: Development, Preview, Production separately
- Or set for "All" environments
- Check Vercel → Project → Settings → Environment Variables and verify which environments each var is enabled for

### 5. Var Set After Build Was Already Running

**Symptom:** Just added a var to Vercel but the current build doesn't see it.

**Cause:** Builds that started before the var was added don't see the new var.

**Fix:** Trigger a new deployment after adding vars. The new build will pick them up.

### 6. env.local Not Loaded for Tests

**Symptom:** Tests pass locally but fail in CI because they try to connect to Supabase.

**Cause:** `vitest` or `jest` may not load `.env.local` by default.

**Fix:** Load env in test setup:
```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import { loadEnv } from 'vite'

export default defineConfig(({ mode }) => ({
  test: {
    env: loadEnv(mode, process.cwd(), ''),
  },
}))
```

Or set test vars in `vitest.config.ts` `define` section for values that should be mocked in CI.

## Checking Env Vars in Deployment

```bash
# Vercel CLI — pull current env vars to local
vercel env pull .env.local

# List all vars for current project
vercel env ls

# Check if a specific var is set for production
vercel env ls | grep SUPABASE_SERVICE_ROLE_KEY
```

## The NEXT_PUBLIC_ Decision Rule

**Yes, add NEXT_PUBLIC_:**
- Supabase URL (not sensitive, needed by browser)
- Supabase anon key (public by design, needed by browser)
- Stripe publishable key (public by design, needed by browser)
- Site URL for client-side redirects

**No, never add NEXT_PUBLIC_:**
- Supabase service role key
- Stripe secret key
- Anthropic API key
- Admin secret / signing key
- Database connection strings
- Any key that says "secret", "private", or "service"
