# Twelve-Factor Config

## The Core Principle

Configuration that changes between environments (development, staging, production) should be in environment variables, not in code.

Config = everything that varies between deployments:
- Credentials and secrets
- API endpoints
- Feature flags (sometimes)
- Database connection strings
- Third-party service IDs

## What Belongs in Code vs Env Vars

```
IN CODE (same everywhere):
- Application logic
- UI components
- Route structure
- Business rules
- Default values for non-sensitive settings

IN ENV VARS (varies per environment):
- API keys and secrets
- Database URLs
- External service endpoints
- OAuth client IDs and secrets
- Domain names and base URLs
```

## Environment Variable Naming

Next.js exposes variables to the browser ONLY if prefixed `NEXT_PUBLIC_`:

```
NEXT_PUBLIC_SUPABASE_URL          → available in browser (by design)
NEXT_PUBLIC_SUPABASE_ANON_KEY     → available in browser (by design)
NEXT_PUBLIC_GA_ID                 → available in browser (by design)
NEXT_PUBLIC_APP_URL               → available in browser (for og:url, etc.)

ANTHROPIC_API_KEY                 → server only
SUPABASE_SERVICE_ROLE_KEY         → server only
STRIPE_SECRET_KEY                 → server only
ADMIN_SECRET                      → server only
```

The rule: if it would be dangerous to expose publicly, it NEVER gets `NEXT_PUBLIC_`.

## Environment Files

```
.env.local              → local development, never committed
.env.example            → template with variable names but no values, committed
.env.test.local         → test environment overrides, never committed
```

Never commit `.env.local`. Always maintain `.env.example` with all required variables documented:

```bash
# .env.example
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
ANTHROPIC_API_KEY=sk-ant-...
ADMIN_SECRET=generate-with-openssl-rand-hex-32
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
RESEND_API_KEY=re_...
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

## Fail Fast on Missing Config

Catch missing configuration at startup, not at first use:

```typescript
// lib/config.ts
function requireEnv(key: string): string {
  const value = process.env[key]
  if (!value) throw new Error(`Required env var ${key} is not set`)
  return value
}

export const config = {
  supabaseUrl: requireEnv('NEXT_PUBLIC_SUPABASE_URL'),
  supabaseAnonKey: requireEnv('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
  supabaseServiceRole: requireEnv('SUPABASE_SERVICE_ROLE_KEY'),
  anthropicApiKey: requireEnv('ANTHROPIC_API_KEY'),
  adminSecret: requireEnv('ADMIN_SECRET'),
  appUrl: process.env.NEXT_PUBLIC_APP_URL ?? 'http://localhost:3000',
}
```

This throws at module import time if required variables are missing — caught in development before any real request.

## Multi-Environment Management

Vercel handles per-environment variables natively:
- `Development` env → `.env.local` takes precedence
- `Preview` env → pull request previews use test/sandbox keys
- `Production` env → live keys

Always use test API keys (Stripe test, Supabase staging) in Preview environments. Never use production keys in Preview.

## Config in Tests

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    env: {
      NEXT_PUBLIC_SUPABASE_URL: 'http://localhost:54321',
      NEXT_PUBLIC_SUPABASE_ANON_KEY: 'test-key',
      SUPABASE_SERVICE_ROLE_KEY: 'test-service-key',
      // Only set what's needed for tests
    },
  },
})
```
