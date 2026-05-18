# Failure: Missing Environment Variable

## Why This Fails Silently

Missing env vars are deceptive. `process.env.SOME_KEY` returns `undefined` — not an error. Code that uses the value often fails later, in a completely different place, with a confusing error like "Cannot read properties of undefined" or "Invalid API key." The actual cause (missing env var) is hidden. In the worst case, the app boots and runs fine until the code path that needs the var is hit in production.

## NEXT_PUBLIC_ vs Server-Only Vars

Next.js has two scopes for env vars:

- **`NEXT_PUBLIC_`** prefix: bundled into the client-side JavaScript at build time. Available in browser. These are public — they ship in the JS bundle that anyone can read.
- **No prefix**: server-only. Available in Server Components, Route Handlers, API routes, and `getServerSideProps`. Never sent to the browser.

Common mistakes:
- Using a non-prefixed var in a Client Component — it silently resolves to `undefined` in the browser, no error.
- Putting a secret key in a `NEXT_PUBLIC_` var — it becomes public.
- Assuming `NEXT_PUBLIC_` vars work at runtime — they are replaced at **build time**; if you change them, you must rebuild.

## Build vs Runtime Environment

Next.js `NEXT_PUBLIC_` vars are inlined at build time via string substitution. The built artifact has the literal value baked in, not a reference to an env var. This means:

1. Vercel's "production" env vars must be set **before** the build runs, not after.
2. Changing a `NEXT_PUBLIC_` var requires a new deployment — restarting the server has no effect.
3. Server-only vars (no prefix) are read at runtime — they can be changed without rebuilding, but require a server restart.

## Vercel Env Var Scoping

Vercel has three scopes: Production, Preview, and Development. Getting this wrong causes "it works in preview but not in production" failures.

- A var set only in Production won't exist in Preview deployments.
- Pull Request previews run in the Preview scope.
- `vercel env pull` pulls Development-scoped vars into your local `.env.local`.
- If a var is missing from Production but present in Preview, the Production deployment silently fails.

Always audit: **which scopes does each var need?** Most vars need all three.

## Defensive getEnv() Helper

Instead of scattering `process.env.X` throughout the codebase and hoping for the best, centralise access with a helper that fails loudly at startup:

```typescript
// lib/env.ts — server-side only
export function getEnv(key: string): string {
  const value = process.env[key];
  if (!value) {
    throw new Error(
      `Missing required environment variable: "${key}". ` +
      `Check your .env.local (development) or Vercel dashboard (production).`
    );
  }
  return value;
}

// Usage — fails at module load time if missing, not deep in a request
const stripe = new Stripe(getEnv("STRIPE_SECRET_KEY"));
const supabaseUrl = getEnv("NEXT_PUBLIC_SUPABASE_URL");
```

For a full env schema, use `zod` to validate and type all env vars at startup:

```typescript
import { z } from "zod";

const EnvSchema = z.object({
  DATABASE_URL: z.string().url(),
  STRIPE_SECRET_KEY: z.string().startsWith("sk_"),
  ANTHROPIC_API_KEY: z.string().startsWith("sk-ant-"),
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
});

export const env = EnvSchema.parse(process.env); // throws on startup if invalid
```

This moves env failures to startup — a `500` on the first request or a crash during deploy, not a silent `undefined` buried in a payment flow.

## Key Rules

- **Never use `process.env.X` directly in business logic** — go through a typed, validated accessor.
- **`NEXT_PUBLIC_` vars are public and build-time** — no secrets, rebuild required to change them.
- **Verify all three Vercel scopes** when a var "works locally but not in production."
- **Fail loudly at startup**, not silently at call time — missing vars should crash the process early.
- **Add required vars to a `.env.example` file** — document every var the project needs.
- **Never commit `.env.local` or `.env`** — they're in `.gitignore` for a reason.
