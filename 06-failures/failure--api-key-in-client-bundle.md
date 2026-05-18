# Failure: API Key in Client-Side Bundle

## Overview
Any secret, API key, or credential included in client-side JavaScript is publicly accessible. Modern bundlers (Webpack, Vite, esbuild) inline environment variables into the JavaScript bundle at build time. Anyone who opens their browser DevTools, downloads the bundle, or searches GitHub for the key can find it. Services discovered via leaked client-side keys have had their APIs abused, accumulated unexpected costs, and suffered data exfiltration — all from code that "only the app should use."

## How It Gets Into the Bundle

```typescript
// vite.config.ts — DANGEROUS
export default defineConfig({
  define: {
    "process.env.STRIPE_SECRET_KEY": JSON.stringify(process.env.STRIPE_SECRET_KEY),
    // ↑ this secret is now in the JavaScript bundle
  }
});

// Next.js — DANGEROUS
// Any variable prefixed NEXT_PUBLIC_ is in the client bundle
NEXT_PUBLIC_STRIPE_SECRET_KEY=sk_live_...  # never do this

// .env file referenced in browser code — DANGEROUS
const client = new Stripe(import.meta.env.VITE_STRIPE_SECRET_KEY);
// ↑ if VITE_STRIPE_SECRET_KEY contains the secret key, it's in the bundle
```

## The Attack Is Trivial

```bash
# Attacker finds your site, downloads the JS bundle
curl https://yourapp.com/_next/static/chunks/app.js | grep -o 'sk_live_[a-zA-Z0-9]*'
# → sk_live_AbCdEfGhIjKlMnOpQrStUv

# Now they have your Stripe secret key and can:
# - Create charges against your merchant account
# - Enumerate customer data
# - Issue refunds
# - Create payouts
```

This takes 30 seconds and requires no hacking ability. It is not an advanced attack.

## What Is Safe to Expose in the Client

```bash
# Safe: public keys, publishable keys, URLs that are meant to be public
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_...  # publishable = OK
NEXT_PUBLIC_SUPABASE_URL=https://abc.supabase.co  # URL = OK
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...  # anon key = OK (Supabase RLS controls access)
NEXT_PUBLIC_APP_URL=https://myapp.com  # URL = OK
```

Not safe:
```bash
# Never in NEXT_PUBLIC_ / VITE_:
STRIPE_SECRET_KEY=sk_live_...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
OPENAI_API_KEY=sk-...
TWILIO_AUTH_TOKEN=...
AWS_SECRET_ACCESS_KEY=...
ADMIN_SECRET=...
```

## The Fix: Backend Proxy Route

All API calls that require a secret key go through your own backend:

```typescript
// WRONG: calling Stripe directly from the browser
// components/PaymentForm.tsx
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY); // secret in bundle
const paymentIntent = await stripe.paymentIntents.create({ amount, currency });

// RIGHT: call your own API route
// components/PaymentForm.tsx
const response = await fetch("/api/payment-intent", {
  method: "POST",
  body: JSON.stringify({ amount, currency }),
});
const { clientSecret } = await response.json();
const stripe = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY);
// clientSecret is safe to use in browser — it allows only one payment

// app/api/payment-intent/route.ts (SERVER ONLY)
import "server-only";
import Stripe from "stripe";
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!); // safe: server only

export async function POST(req: Request) {
  const { amount, currency } = await req.json();
  const intent = await stripe.paymentIntents.create({ amount, currency });
  return Response.json({ clientSecret: intent.client_secret });
}
```

## Detecting Leaked Keys

```bash
# Search your built bundle for known key prefixes
grep -r "sk_live_" .next/static/
grep -r "sk-" .next/static/  # OpenAI
grep -r "AKIA" .next/static/  # AWS

# Or use truffleHog / gitleaks in CI
trufflehog filesystem .next/static/ --only-verified
```

Add this as a CI step. If any secret pattern is found in the built output, fail the build.

## Key Rules
- Never put a secret key in a `NEXT_PUBLIC_` / `VITE_` variable — these go into the bundle
- All calls using secret keys go through backend API routes, not directly from the browser
- Audit built bundle output for secrets: `grep -r "sk_live" .next/static/`
- Publishable/public keys (Stripe pk_, Supabase anon key) are designed to be in the browser
- Service role keys, secret keys, auth tokens → server only, enforced with `import "server-only"`
- Rotate any key that has ever been in a client bundle — assume it was already scraped
- Run gitleaks or truffleHog in CI to catch secrets in git history and built artifacts
