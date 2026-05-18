# Failure: Environment Variable Leak to Client Bundle

## Overview
The `NEXT_PUBLIC_` prefix tells Next.js to inline the variable's value into the client-side JavaScript bundle at build time. Any variable with this prefix is readable by anyone who downloads your JS — it's public. Server-only secrets (API keys, service role keys, signing secrets) are safe in Server Components and Route Handlers but become a critical security incident if accidentally prefixed with `NEXT_PUBLIC_`.

## How the Leak Happens

```ts
// .env.local
NEXT_PUBLIC_SUPABASE_URL=https://xyz.supabase.co     // SAFE — intended to be public
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...                 // SAFE — public anon key
SUPABASE_SERVICE_ROLE_KEY=eyJ...                     // SAFE as-is — server only

// The mistake:
NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY=eyJ...         // DANGEROUS — now in client bundle
NEXT_PUBLIC_STRIPE_SECRET_KEY=sk_live_...            // DANGEROUS
NEXT_PUBLIC_ADMIN_SECRET=my-signing-secret           // DANGEROUS
```

Once in the bundle, the value is visible in:
- Browser DevTools → Sources → any JS file
- `curl https://yoursite.com/_next/static/chunks/app.js | grep "sk_live"`
- Any build artifact, CDN edge cache, or logged request

## Where Each Variable is Safe

```ts
// Server Component — safe
export default async function Page() {
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY  // never sent to browser
  return <div />
}

// Route Handler — safe
export async function POST(req: Request) {
  const secret = process.env.STRIPE_SECRET_KEY  // server-side only
}

// Client Component — DANGEROUS for secrets
'use client'
export function Component() {
  const key = process.env.NEXT_PUBLIC_STRIPE_SECRET_KEY  // in the JS bundle
  // Any non-NEXT_PUBLIC_ var here is just `undefined` at runtime
}
```

## Audit: Find Leaked Variables

```bash
# Build first, then search the output
ANALYZE=true next build

# Search built JS for secret patterns
grep -r "sk_live" .next/static/chunks/
grep -r "service_role" .next/static/chunks/
grep -r "SUPABASE_SERVICE" .next/static/chunks/
```

Or use `@next/bundle-analyzer`:

```js
// next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
})
module.exports = withBundleAnalyzer({})
```

## Fix: Proxy Through API Route

If a client component needs data that requires a secret, proxy it:

```ts
// app/api/protected-data/route.ts — runs server-side
export async function GET() {
  const data = await fetchWithSecret(process.env.INTERNAL_API_KEY!)
  return Response.json(data)  // return only what the client needs
}
```

```tsx
// Client component — calls the proxy, never sees the key
'use client'
const data = await fetch('/api/protected-data').then(r => r.json())
```

## Key Rules
- `NEXT_PUBLIC_` = bundled into client JS = public to anyone — treat it as such
- Only two kinds of values belong in `NEXT_PUBLIC_` variables: public API keys (Supabase anon, Stripe publishable) and non-secret config (site domain, feature flags)
- Server-only secrets: `SUPABASE_SERVICE_ROLE_KEY`, `STRIPE_SECRET_KEY`, `ADMIN_SECRET`, `ANTHROPIC_API_KEY`, signing secrets, DB passwords
- After any `.env` change, audit with `grep -r "NEXT_PUBLIC" .env*` and verify each is safe to expose
- Add a CI step: `grep -r "sk_live\|service_role" .next/static/ && exit 1 || exit 0`
- If a key is leaked: rotate it immediately, then audit how/when it was exposed
