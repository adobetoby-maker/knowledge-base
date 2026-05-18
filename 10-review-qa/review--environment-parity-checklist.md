# Review: Environment Parity Checklist

## Overview
Environment parity is the principle that development, staging, and production environments should
differ as little as possible. "Works on my machine" bugs and staging-passes-but-production-fails
incidents are almost always caused by environment differences. The discipline of maintaining parity
prevents an entire class of deployment surprises.

## Implementation

### Node/Runtime Version Parity
```json
// package.json — declare the required Node version
{
  "engines": {
    "node": ">=20.0.0",
    "npm": ">=10.0.0"
  }
}
```
```
# .nvmrc or .node-version — pins exact version for local dev
20.11.0
```
```dockerfile
# Dockerfile — must match .nvmrc
FROM node:20.11.0-alpine
```
```yaml
# CI (GitHub Actions)
- uses: actions/setup-node@v4
  with:
    node-version-file: '.nvmrc'   # reads from .nvmrc automatically
```

### OS-Level Dependencies
```dockerfile
# Declare ALL native dependencies in Dockerfile — not just npm packages
FROM node:20.11.0-alpine
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    # Any OS package your npm deps need for native compilation
    libc6-compat
```
Common gotchas:
- `sharp` (image processing) requires native libraries
- `puppeteer` requires Chromium + specific system libs
- `bcrypt` (not bcryptjs) compiles native code
If your team uses macOS and deploys to Linux, native compilation differences are a common failure point.

### Secrets Management Parity
```
Development:    .env file (gitignored) — developer-managed
Staging:        Same secret manager as production (Vercel env vars, AWS Secrets Manager, etc.)
Production:     Same secret manager

✗ Antipattern:
  Dev:     .env file
  Staging: hardcoded in CI pipeline YAML
  Prod:    AWS Secrets Manager

✓ Best practice:
  All environments use the same secret manager with environment-specific namespaces
  Dev can use .env as override ONLY — not as primary secret storage
```

### Database Schema Sync
```bash
# Verify staging/prod schema matches migrations
# Run this as part of deployment health check:
npx prisma migrate status         # shows pending migrations
# or
alembic current                   # shows current migration in DB vs codebase
```
```
Rule: Never run raw SQL against staging/prod directly.
      All schema changes must go through migration files.
      Staging must have all migrations that prod has PLUS any unreleased migrations.
```

### Feature Flag Defaults
```ts
// Feature flags that differ between environments cause "works in staging" bugs
// Document the default for each environment:

const flags = {
  NEW_CHECKOUT_FLOW: {
    development: true,    // always on for dev
    staging: true,        // on in staging for testing
    production: false,    // off in prod until release decision
  },
};

// ✗ Antipattern: checking hostname to determine behavior
if (window.location.hostname === 'staging.myapp.com') {
  // staging-only code — this WILL get deployed to production accidentally
}
```

### No Dev-Only Code Paths in Production Bundle
```ts
// ✓ Safe: process.env.NODE_ENV is tree-shaken by bundlers
if (process.env.NODE_ENV !== 'production') {
  console.log('debug data:', payload);
}

// ✗ Risky: custom env flags that may not be set correctly in prod
if (process.env.DISABLE_AUTH === 'true') {  // what if this is set in prod by mistake?
  skipAuthCheck();
}
```
```bash
# Audit for dev-only backdoors before release:
grep -r "DISABLE_AUTH\|skipAuth\|bypassAuth\|devMode" src/
```

### Staging Gets Prod Deploys First
```
Deployment order:
1. Run migrations on staging
2. Deploy code to staging
3. Run smoke tests on staging
4. Run migrations on production
5. Deploy code to production
6. Run smoke tests on production

If step 3 fails: stop. Do not deploy to production.
The staging deploy is a production dress rehearsal — treat staging failures as production risks.
```

## Key Rules
- Every environment must use the same Node version — use `.nvmrc` and read it in CI
- Native npm packages (sharp, bcrypt, puppeteer) must be tested on the same OS architecture as production
- All schema changes go through migration files — raw SQL against the database breaks the migration chain
- Feature flags must have explicitly configured defaults per environment — never infer environment from hostname or IP
- Staging must receive every deployment before production — staging failures block production deploys
- Secrets must come from the same secret management system in all non-local environments
- If a bug "only happens in production," the first question to answer is: what is different between staging and production?
