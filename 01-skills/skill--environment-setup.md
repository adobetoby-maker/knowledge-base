# Skill: Environment Setup

## Overview

A well-configured development environment setup gets new developers running in under 30 minutes and prevents "works on my machine" bugs. The setup should be automated, documented, and validated — a setup script that prints a success message without actually checking that everything works is worse than no script.

## .env Validation at Startup

```ts
// lib/env.ts — validate all required vars at module load
import { z } from 'zod'

const envSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  ANTHROPIC_API_KEY: z.string().startsWith('sk-ant-'),
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
})

const result = envSchema.safeParse(process.env)
if (!result.success) {
  const issues = result.error.issues
    .map(i => `  ${i.path.join('.')}: ${i.message}`)
    .join('\n')
  throw new Error(`Missing or invalid environment variables:\n${issues}\n\nSee .env.example for required variables.`)
}

export const env = result.data
```

## .env.example Template

```bash
# .env.local — copy from this file, fill in values
# Never commit .env.local

# Supabase (Settings > API in your project dashboard)
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...   # SERVER ONLY — never use NEXT_PUBLIC_

# AI features
ANTHROPIC_API_KEY=sk-ant-...

# Optional: override for local development
# DATABASE_DIRECT_URL=postgresql://postgres:password@localhost:5432/mydb
```

## Setup Script

```bash
#!/usr/bin/env bash
# scripts/setup.sh
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

check() { command -v "$1" >/dev/null 2>&1; }

echo "Checking prerequisites..."
check node || { echo -e "${RED}Node.js >= 20 required: https://nodejs.org${NC}"; exit 1; }
check npm  || { echo -e "${RED}npm required${NC}"; exit 1; }

NODE_VERSION=$(node -e "process.exit(parseInt(process.version.slice(1)) < 20 ? 1 : 0)" 2>&1) || {
  echo -e "${RED}Node.js >= 20 required (you have $(node -v))${NC}"; exit 1
}

echo "Installing dependencies..."
npm install

if [ ! -f .env.local ]; then
  cp .env.example .env.local
  echo -e "${GREEN}Created .env.local — fill in your API keys before running${NC}"
else
  echo ".env.local already exists"
fi

echo -e "${GREEN}Setup complete! Run: npm run dev${NC}"
```

## Secret Sharing for Teams

```bash
# Option 1: Doppler (recommended for teams)
# npx doppler setup
# doppler run -- npm run dev

# Option 2: 1Password CLI
# eval $(op inject -i .env.example -o .env.local)

# Option 3: Vercel env pull (for Vercel projects)
# npx vercel env pull .env.local
```

## Checking Setup Completeness

```ts
// app/api/health/route.ts — check all services are reachable
export async function GET() {
  const checks: Record<string, boolean> = {}

  try {
    await db.query.users.findFirst()  // DB reachable
    checks.database = true
  } catch { checks.database = false }

  const allOk = Object.values(checks).every(Boolean)
  return Response.json(checks, { status: allOk ? 200 : 503 })
}
```

## Key Rules

- Validate all env vars at startup with descriptive errors — a "Cannot read properties of undefined" at runtime is much harder to diagnose.
- `.env.example` must be kept in sync with actual required vars — add a CI check that compares it against the schema.
- The setup script should print WHERE to get each required API key, not just that it's missing.
- Never commit actual secrets — `.env.local` must be in `.gitignore` (it's included by default in Next.js).
- Onboarding time > 30 minutes is a bug — measure it with new team members and fix every friction point.
