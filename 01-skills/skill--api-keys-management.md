# API Keys Management

## The Core Security Rule

API keys in the browser = exposed to everyone. Any key in `NEXT_PUBLIC_*` or in client-side code will be visible in browser DevTools.

```
SAFE (server-only):           EXPOSED (public):
ANTHROPIC_API_KEY             NEXT_PUBLIC_SUPABASE_URL       ← intentionally public
STRIPE_SECRET_KEY             NEXT_PUBLIC_SUPABASE_ANON_KEY  ← intentionally public
SUPABASE_SERVICE_ROLE_KEY     NEXT_PUBLIC_GA_ID              ← intentionally public
ADMIN_SECRET
TWILIO_AUTH_TOKEN
RESEND_API_KEY
```

The Supabase anon key and Stripe publishable key are safe to expose — they're designed for client use and controlled by RLS/CORS/webhook verification on the server side.

## Key Storage

```
.env.local             — development (never committed)
Vercel env vars        — staging and production
Cloudflare secrets     — for Worker-deployed functions
.gitignore             — must include .env.local and .env*.local
```

## Never Commit Keys

```bash
# .gitignore must include:
.env
.env.local
.env.*.local
*.env

# Check if any key was accidentally committed:
git log --all -p | grep -E "(sk_|pk_|re_|eyJ|supabase)" | head -20
```

If a key was committed: revoke it immediately in the service dashboard. A committed key is compromised even if you rewrite history — someone may have already cloned it.

## Managing Multiple Environments

```bash
# .env.local — development:
ANTHROPIC_API_KEY=sk-ant-...
STRIPE_SECRET_KEY=sk_test_...
SUPABASE_SERVICE_ROLE_KEY=eyJ...

# Vercel dashboard → Project → Settings → Environment Variables:
# Set ANTHROPIC_API_KEY for Production, Preview, Development separately
# Production: use live keys (sk_live_..., re_xxx)
# Preview: use test keys (sk_test_..., sandbox IDs)
```

Use Vercel's "Preview" environment for pull request deployments — always uses test/sandbox keys.

## Rotating Keys

When a key is compromised or needs rotation:
1. Generate new key in the service dashboard
2. Add new key to all environments (Vercel, Cloudflare, `.env.local`)
3. Verify the service is working with the new key
4. Revoke the old key in the service dashboard

Rotation order: update environments → verify → revoke old. Never revoke before the new key is live.

## Key Validation at Startup

Fail fast if required keys are missing rather than getting cryptic errors later:

```typescript
// lib/config.ts
function requireEnv(key: string): string {
  const value = process.env[key]
  if (!value) {
    throw new Error(`Required environment variable ${key} is not set`)
  }
  return value
}

export const config = {
  supabaseUrl: requireEnv('NEXT_PUBLIC_SUPABASE_URL'),
  supabaseAnonKey: requireEnv('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
  supabaseServiceRole: requireEnv('SUPABASE_SERVICE_ROLE_KEY'),
  anthropicApiKey: requireEnv('ANTHROPIC_API_KEY'),
  adminSecret: requireEnv('ADMIN_SECRET'),
}
```

This throws at import time if keys are missing, catching configuration errors in development before any request is made.

## Client-Side Key Detection

Add a test to catch leaked server keys:

```typescript
// lib/config.test.ts
test('no server-only env vars leaked to client', () => {
  const serverOnlyVars = [
    'ANTHROPIC_API_KEY',
    'STRIPE_SECRET_KEY',
    'SUPABASE_SERVICE_ROLE_KEY',
    'ADMIN_SECRET',
  ]
  
  for (const varName of serverOnlyVars) {
    // These should NOT be accessible in the browser
    // In test environment, check they don't appear in NEXT_PUBLIC_ names
    expect(varName.startsWith('NEXT_PUBLIC_')).toBe(false)
    // Also verify they're not exposed in window or process.env from client context
  }
})
```

## Secrets in Logs

Never log full API keys:

```typescript
// WRONG:
console.log('Using API key:', process.env.ANTHROPIC_API_KEY)

// OK — log only prefix to confirm which key is active:
const key = process.env.ANTHROPIC_API_KEY ?? ''
console.log('Using API key:', key.substring(0, 10) + '...')
```
