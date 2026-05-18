# Principle: Developer Experience (DX)

## Overview

Developer experience is how fast a developer can go from idea to working code. Poor DX multiplies the cost of every feature: slow builds compound across hundreds of daily cycles, confusing errors require investigation before any fix begins, and undocumented setup delays every new contributor. DX investment pays back on every task.

## Fast Local Dev Startup

```bash
# Target: < 10 seconds from clone to running app
# Bad: 45 seconds for npm install + db setup + seed + build
# Good: docker compose up (one command, everything included)

# Measure your startup time and track it
time npm run dev  # add to README
```

The 10-second target matters because developers run this dozens of times per day. At 45 seconds vs 10 seconds, 20 restarts/day = 11 minutes lost daily.

## Clear Error Messages with Fix Hints

```ts
// Bad error message
throw new Error('Configuration error')

// Good error message — names the problem and the fix
throw new Error(
  `Missing required environment variable: SUPABASE_SERVICE_ROLE_KEY\n` +
  `Add it to .env.local. See .env.example for reference.`
)

// Good Zod validation error — shows exactly which field failed
const result = configSchema.safeParse(process.env)
if (!result.success) {
  const issues = result.error.issues.map(i => `  ${i.path.join('.')}: ${i.message}`)
  throw new Error(`Invalid configuration:\n${issues.join('\n')}`)
}
```

## .env.example as Contract

```bash
# .env.example — committed to git, shows all required vars
# Never commit actual secrets

NEXT_PUBLIC_SUPABASE_URL=           # Supabase project URL (Settings > API)
NEXT_PUBLIC_SUPABASE_ANON_KEY=      # Anon key (Settings > API)
SUPABASE_SERVICE_ROLE_KEY=          # Service role (Settings > API) — server only
ANTHROPIC_API_KEY=                  # From console.anthropic.com
```

Comments in `.env.example` should say WHERE to get the value, not just what it is.

## Setup Script

```bash
#!/bin/bash
# scripts/setup.sh — run once after clone

set -e

echo "Checking prerequisites..."
command -v node >/dev/null 2>&1 || { echo "Node.js required (>= 20)"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Docker required"; exit 1; }

echo "Installing dependencies..."
npm install

echo "Checking environment..."
if [ ! -f .env.local ]; then
  cp .env.example .env.local
  echo "Created .env.local — fill in your API keys before running"
fi

echo "Starting local services..."
docker compose up -d

echo "Running migrations..."
npm run db:migrate

echo "Done. Run: npm run dev"
```

## Onboarding Time Budget

Target: a new developer should have the app running locally in under 30 minutes on their first day. Measure this by having new hires time-record it. Every minute over 30 is a bug in the setup process.

## Key Rules

- Treat a "setup took 2 hours" report as a P1 bug — it will repeat for every future contributor.
- `.env.example` must stay in sync with actual required vars — a stale example is worse than none (it misleads).
- Error messages are documentation — they're read more than README files. Invest in them.
- Fast feedback loops beat powerful tools — a 2-second lint + typecheck beats a 30-second full build for incremental DX.
- Automate the "boring" onboarding steps (npm install, DB setup, seed) into a single command.
