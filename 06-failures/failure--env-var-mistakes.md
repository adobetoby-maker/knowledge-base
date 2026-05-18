# Failure Patterns: Environment Variable Mistakes

## NEXT_PUBLIC_ Exposes to Browser

Any variable prefixed `NEXT_PUBLIC_` is embedded in the browser bundle at build time. Anyone can view it in the page source.

Safe to expose (public keys):
- `NEXT_PUBLIC_SUPABASE_URL` — not secret, just an endpoint
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` — has RLS protecting data
- `NEXT_PUBLIC_GA_MEASUREMENT_ID` — analytics ID, by design public

NEVER expose with `NEXT_PUBLIC_`:
- `SUPABASE_SERVICE_ROLE_KEY` — bypasses ALL RLS, full database access
- `ANTHROPIC_API_KEY` — would let anyone make API calls at your expense
- `ADMIN_SECRET` — signs admin session cookies
- `STRIPE_SECRET_KEY` — payment processing key
- Any database password or private key

```typescript
// WRONG — service role key exposed to client:
const NEXT_PUBLIC_SUPABASE_SERVICE_ROLE = process.env.NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY

// CORRECT — server-only:
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY  // no NEXT_PUBLIC_
```

## Build-Time Missing Variable

Next.js bakes `NEXT_PUBLIC_` values at build time. If the variable is missing at build time, it becomes `undefined` in the bundle — even if you set it later at runtime.

```bash
# This build will have NEXT_PUBLIC_SUPABASE_URL as undefined:
NEXT_PUBLIC_SUPABASE_URL='' npm run build

# Check for build-time values in CI:
# Vercel injects them automatically if set in the dashboard
```

## Validation at Startup

Fail fast if required env vars are missing — don't let the app run with missing config and surface a confusing runtime error:

```typescript
// lib/env.ts
function requireEnv(name: string): string {
  const value = process.env[name]
  if (!value) throw new Error(`Missing required environment variable: ${name}`)
  return value
}

export const env = {
  supabaseUrl: requireEnv('NEXT_PUBLIC_SUPABASE_URL'),
  supabaseAnonKey: requireEnv('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
  // Server-only — not exported from this file if file could be imported client-side
}

// For server-only env:
// lib/server-env.ts (never imported by client-side code)
export const serverEnv = {
  serviceRoleKey: requireEnv('SUPABASE_SERVICE_ROLE_KEY'),
  anthropicApiKey: requireEnv('ANTHROPIC_API_KEY'),
}
```

## .env Files Not Loading

Common causes:
- `.env.local` is in `.gitignore` (correct) but you forgot to create it locally
- Variable defined in `.env` but `.env.local` overrides with empty string
- Variable defined correctly but app loaded from a different directory

```bash
# Verify which env file is being loaded:
node -e "console.log(process.env.NEXT_PUBLIC_SUPABASE_URL)"

# For Vercel functions, env vars are set in dashboard, not .env files:
# Settings → Environment Variables
```

## Dynamic Env Access (Won't Work)

```typescript
// WRONG — Next.js can't analyze dynamic access:
const key = `NEXT_PUBLIC_${envName}_URL`
const value = process.env[key]  // always undefined

// CORRECT — static string literal:
const value = process.env.NEXT_PUBLIC_SUPABASE_URL
```

`process.env` in Next.js is statically analyzed at build time. Only literal string access works for `NEXT_PUBLIC_` variables.

## Missing .env.example

```bash
# .env.example should document all required variables (with placeholder values):
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
ANTHROPIC_API_KEY=sk-ant-...
ADMIN_SECRET=your-secret-here
```

Never commit `.env.local` (it has real secrets). Always commit `.env.example` (it has placeholders).
