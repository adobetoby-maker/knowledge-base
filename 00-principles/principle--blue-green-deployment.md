# Principle: Blue-Green Deployment

## Overview

Blue-green deployment runs two identical production environments (blue and green). One is live; the other is idle. To deploy, you update the idle environment, then switch traffic. If something breaks, you switch back instantly. No downtime, no risky in-place upgrades.

## The Model

```
Blue (live)   → receives 100% of traffic
Green (idle)  → running old version

Deploy new version to Green:
Green (updated) → still receiving 0% traffic
                → run smoke tests, migration checks

Switch:
Green (updated) → receives 100% of traffic (new live)
Blue (old)      → receives 0% (standby for rollback)
```

Rollback = flip traffic back to Blue. Instant.

## Database Migrations Must Be Backward Compatible

The hard part of blue-green: the database is shared between both environments. During traffic switch, both old and new code may be running. Migrations must be safe for both versions simultaneously.

```sql
-- BAD: rename column in one step — old code can't read new column name
ALTER TABLE users RENAME COLUMN email TO email_address;

-- GOOD: three-phase migration
-- Phase 1 (deploy with Blue/old): add new column, copy data via trigger
ALTER TABLE users ADD COLUMN email_address text;
UPDATE users SET email_address = email;

-- Phase 2 (deploy with Green/new): new code uses email_address
-- Both columns exist, both versions work

-- Phase 3 (once all Blue traffic drained): drop old column
ALTER TABLE users DROP COLUMN email;
```

This expands → migrates → contracts. Each phase is safe with both code versions.

## Implementation on Vercel

Vercel does this automatically with preview deployments and instant rollback:

```bash
# Deploy to preview URL (green)
vercel deploy

# Test the preview deployment
curl https://your-app-abc123.vercel.app/api/health

# Promote to production (traffic switch)
vercel promote <deployment-url>

# Rollback if needed (switch back)
vercel rollback
```

## Implementation on Fly.io

```toml
# fly.toml
[deploy]
  strategy = "bluegreen"
  wait_timeout = "300s"
```

```bash
# Fly.io handles the switch automatically
fly deploy

# Rollback
fly releases list
fly deploy --image registry.fly.io/myapp:<previous-version>
```

## Implementation on Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      slot: green
  template:
    metadata:
      labels:
        app: myapp
        slot: green
    spec:
      containers:
      - name: app
        image: myapp:v2
---
# Service points to active slot
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: myapp
    slot: green   # Change to 'blue' to roll back
```

## Smoke Tests Before Traffic Switch

```ts
// scripts/smoke-test.ts
async function smokeTest(baseUrl: string) {
  const checks = [
    { path: '/api/health', expected: 200 },
    { path: '/api/version', expected: 200 },
    { path: '/login', expected: 200 },
  ]

  for (const check of checks) {
    const res = await fetch(`${baseUrl}${check.path}`)
    if (res.status !== check.expected) {
      throw new Error(`Smoke test failed: ${check.path} returned ${res.status}`)
    }
  }

  console.log('All smoke tests passed')
}

// Run against green before promoting
await smokeTest(process.env.GREEN_URL)
```

## Key Rules

- Database migrations must work with both the old and new version of the app simultaneously — use expand/contract migrations.
- Smoke test the idle environment before switching traffic — check health endpoints, critical API routes, database connectivity.
- The traffic switch should be instantaneous — if it's gradual (canary), that's a different deployment strategy.
- Keep the old environment running for at least 15 minutes after switch — enough time to detect issues and roll back.
- Session state must be in an external store (Redis, DB) — a stateful process can't be swapped without losing in-memory sessions.
