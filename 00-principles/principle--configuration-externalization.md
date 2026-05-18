# Principle: Configuration Externalization

## Overview
Configuration is anything that differs between deployment environments: database connection strings, API keys, feature flags, service URLs, log levels. When configuration lives in source code or committed config files, deploying to a new environment requires code changes — meaning a new build artifact for each environment. Externalizing configuration via environment variables allows the same artifact (the same Docker image, the same compiled binary) to be deployed to dev, staging, and production with different behavior.

## The Twelve-Factor Rule (Factor III)

"An app's config is everything that is likely to vary between deploys (staging, production, developer environments, etc.). Apps sometimes store config as constants in the code. This is a violation of twelve-factor, which requires strict separation of config from code."

The test: could you open-source the codebase right now without exposing any credentials? If no, config is leaking into code.

## What Counts as Configuration

- Database URLs and credentials
- Third-party API keys (Stripe, Sendgrid, Twilio)
- Service endpoints (internal microservice URLs)
- Feature flag values (until using a feature flag service)
- Log levels (`debug` in dev, `info` in prod)
- Port numbers
- JWT secrets, cookie signing keys
- Storage bucket names

## What Does NOT Count as Configuration

- Application logic (conditionals, algorithms)
- Default values baked into product behavior
- Static content (copy, translations — these go in code or CMS, not env vars)

## Detection at Startup, Not at Runtime

Missing configuration should be caught when the process starts, not three hours into production traffic when a code path that needs it is first hit:

```typescript
// config.ts — load and validate at module initialization time
function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value) throw new Error(`Missing required environment variable: ${key}`);
  return value;
}

export const config = {
  databaseUrl: requireEnv("DATABASE_URL"),
  stripeSecretKey: requireEnv("STRIPE_SECRET_KEY"),
  adminSecret: requireEnv("ADMIN_SECRET"),
  // Optional with defaults:
  logLevel: process.env.LOG_LEVEL ?? "info",
  port: Number(process.env.PORT ?? 3000),
};
```

If `DATABASE_URL` is missing, the process crashes immediately on startup with a clear error — not silently during a user's checkout flow.

## Validation With Zod

```typescript
import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  STRIPE_SECRET_KEY: z.string().startsWith("sk_"),
  ADMIN_SECRET: z.string().min(32),
  PORT: z.coerce.number().default(3000),
  LOG_LEVEL: z.enum(["debug", "info", "warn", "error"]).default("info"),
});

export const env = envSchema.parse(process.env);
// Throws on startup with precise validation errors if any required var is missing/invalid
```

## Never Commit Secrets

`.env` files are for local development only. They must be in `.gitignore`:
```
# .gitignore
.env
.env.local
.env.*.local
```

Use `.env.example` (committed) to document what variables are required, with fake placeholder values:
```bash
# .env.example
DATABASE_URL=postgresql://user:password@localhost:5432/mydb
STRIPE_SECRET_KEY=sk_test_REPLACE_ME
ADMIN_SECRET=at-least-32-chars-replace-this
```

## Key Rules
- All configuration via environment variables — zero hardcoded connection strings
- Validate all required vars at startup; fail fast with clear error messages
- `.env` files are in `.gitignore`, always
- `.env.example` is committed with placeholder values to document requirements
- Same Docker image, same compiled binary deploys to every environment — only env vars differ
- Never log full env var values (may contain secrets); log presence/absence only
- Rotate secrets by updating env vars + restarting; no code change, no redeploy of new code
