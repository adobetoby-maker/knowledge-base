# Failure: Vite Environment Variables

## Overview
Vite's environment variable system has a fundamentally different security model than Next.js. In Next.js, only `NEXT_PUBLIC_` prefixed variables are exposed to the client. In Vite, only `VITE_` prefixed variables are exposed — but the inverse mistake is equally dangerous: accidentally giving a secret variable a `VITE_` prefix bundles it into client JavaScript, where any user can read it in DevTools. This is a silent security leak with no build-time warning.

## Vite's Two Variable Contexts

### Client-side variables (VITE_ prefix)
```
VITE_SUPABASE_URL=https://abc.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=eyJhbGci...
```
These are statically inlined into the browser bundle at build time. They appear in the compiled JavaScript and are readable by anyone.

### Server-side variables (no VITE_ prefix)
```
ANTHROPIC_API_KEY=sk-ant-...
DATABASE_URL=postgresql://...
STRIPE_SECRET_KEY=sk_live_...
```
These are available only in server-side code (SSR, server functions). Never exposed to the browser.

## The Critical Error: Wrong Prefix on a Secret

```bash
# WRONG: secret key with VITE_ prefix — will appear in browser bundle
VITE_ANTHROPIC_API_KEY=sk-ant-api03...   # ← This is now visible to every user
VITE_STRIPE_SECRET_KEY=sk_live_...       # ← This is now visible to every user
```

Vite bundles these into the client JavaScript with no warning. The key will appear in the compiled output at `dist/assets/index-[hash].js` and is readable by anyone viewing source.

## Accessing Variables in Code

```typescript
// Client-side code (components, hooks)
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;

// Server-side code (TanStack Start server functions, SSR)
const apiKey = process.env.ANTHROPIC_API_KEY;  // not VITE_ prefix

// Common mistake: accessing process.env in client code
const key = process.env.VITE_SUPABASE_URL;  // undefined in browser — use import.meta.env
```

## TanStack Start (LinguaLens) Specifics

TanStack Start runs on Cloudflare Workers via `@cloudflare/vite-plugin`. The Cloudflare Workers runtime doesn't have `process.env` — it uses the Cloudflare environment bindings:

```typescript
// Server function in TanStack Start
import { createServerFn } from '@tanstack/start';

export const callAI = createServerFn().handler(async (ctx) => {
  // On Cloudflare Workers: use ctx.env (bindings)
  // In local Vite dev: falls back to process.env
  const apiKey = process.env.ANTHROPIC_API_KEY;  // works in both
  // ...
});
```

## .env File Loading Priority

Vite loads `.env` files in this order (later overrides earlier):
```
.env                  # committed baseline (no secrets)
.env.local            # gitignored, local overrides
.env.[mode]           # e.g., .env.production
.env.[mode].local     # gitignored, mode-specific overrides
```

`mode` is `development` by default, `production` during `vite build`.

## Auditing Your Bundle for Secrets

After building, grep the output for known secret prefixes:
```bash
npm run build
grep -r "sk-ant\|sk_live\|sk_test" dist/  # Look for API key patterns
grep -r "ANTHROPIC\|STRIPE_SECRET" dist/  # Look for variable names
```

If any secret appears in `dist/`, a `VITE_` prefix was added to a secret variable — remove it immediately and rotate the key.

## Type Safety for Environment Variables

```typescript
// env.d.ts — TypeScript types for import.meta.env
interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL: string;
  readonly VITE_SUPABASE_PUBLISHABLE_KEY: string;
  // Do NOT declare server-only vars here — they're not available client-side
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

## Key Rules
- Only `VITE_` prefixed variables are included in the browser bundle — treat this as a public API
- API keys, database URLs, and service secrets must NEVER have the `VITE_` prefix
- Use `import.meta.env.VITE_*` in client code; `process.env.*` in server-only code
- `.env.local` is the correct place for local secrets; it must be in `.gitignore`
- After every build, grep `dist/` for secret key patterns to catch accidental exposure
- Unlike Next.js where missing NEXT_PUBLIC_ causes undefined, Vite silently exposes the variable if the prefix is present
