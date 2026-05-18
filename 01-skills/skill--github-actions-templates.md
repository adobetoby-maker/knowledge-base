# Skill: github-actions-templates

**Trigger:** Setting up CI/CD pipelines. Need automated build checks, test runs, deployments, or scheduled tasks via GitHub Actions.
**Invoke:** `/github-actions-templates`
**Returns:** Complete workflow YAML files for common CI patterns.

## When to Invoke
- Setting up CI for a new project
- Automating deployments to Vercel/Cloudflare/Supabase
- Running tests on every PR
- Scheduled jobs (SEO audit, DB cleanup, content generation)
- Release automation

## Basic CI Workflow (build + test on PRs)
```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      
      - run: npm ci
      - run: npm run build
      - run: npm run lint
      - run: npx tsc --noEmit
      - run: npm test          # if tests exist
```

## Vercel Preview Deploy on PR
Vercel handles this automatically via GitHub integration — no custom action needed.
Just: Vercel project → Settings → Git → Connect repo.
Every PR gets an automatic preview URL.

## Supabase Migration on Merge
```yaml
# .github/workflows/db-migrate.yml
name: DB Migrate
on:
  push:
    branches: [main]
    paths:
      - 'supabase/migrations/**'

jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
        with:
          version: latest
      - run: supabase db push
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}
```

## Scheduled Job (weekly SEO audit)
```yaml
# .github/workflows/scheduled-seo.yml
name: Weekly SEO Audit
on:
  schedule:
    - cron: '0 9 * * 1'  # Monday 9am UTC

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci
      - run: node scripts/seo-audit.js
        env:
          NEXT_PUBLIC_URL: ${{ secrets.SITE_URL }}
```

## Secrets Management
```yaml
# Access in workflows:
env:
  DATABASE_URL: ${{ secrets.DATABASE_URL }}
  API_KEY: ${{ secrets.API_KEY }}

# Add secrets:
# GitHub repo → Settings → Secrets and variables → Actions → New secret
```

## Caching Dependencies
```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'  # automatically caches node_modules
```

## What Skill Returns
Complete workflow templates for: monorepo CI, deployment pipelines, database migrations, security scanning, dependency updates, and release automation.
