# Skill: GitHub Actions CI/CD Pipeline

## Overview
A well-structured CI/CD pipeline catches bugs before merge and deploys automatically after merge — without requiring developers to remember manual steps. The key structural decisions: cache node_modules aggressively, cancel in-progress runs for PRs (not main), and keep test and deploy workflows separate so a failed deploy doesn't block the next test run.

## Implementation

### Test Workflow (`.github/workflows/ci.yml`)
```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}
  # Cancel in-progress for PRs; never cancel on main

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: "npm"                   # caches ~/.npm — saves 30-60s per run

      - name: Install dependencies
        run: npm ci                      # ci is faster and reproducible vs install

      - name: Lint
        run: npm run lint

      - name: Typecheck
        run: npm run typecheck

      - name: Test
        run: npm test -- --coverage
        env:
          DATABASE_URL: ${{ secrets.CI_DATABASE_URL }}

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        if: always()
```

### Deploy Workflow (`.github/workflows/deploy.yml`)
```yaml
name: Deploy
on:
  push:
    branches: [main]                     # deploy only on main merge

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production              # requires manual approval in GitHub
    needs: []                            # deploy is independent of test (test runs in CI workflow)
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: "npm"

      - run: npm ci --omit=dev

      - name: Build
        run: npm run build
        env:
          NODE_ENV: production

      - name: Deploy to Vercel
        run: npx vercel --prod --token=${{ secrets.VERCEL_TOKEN }}
        env:
          VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
          VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
```

### Environment Secrets
Store secrets in GitHub → Settings → Secrets and Variables → Actions. Never echo or print secrets in steps. Reference via `${{ secrets.NAME }}`.

### Cache Strategy
```yaml
# For npm: actions/setup-node handles this when cache: "npm" is set
# For custom caches:
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: npm-${{ runner.os }}-${{ hashFiles('package-lock.json') }}
    restore-keys: npm-${{ runner.os }}-
```

## Key Rules
- Separate test and deploy into different workflow files — they have different triggers and different failure semantics
- Use `npm ci` not `npm install` in CI — `ci` is faster, reproducible, and fails if `package-lock.json` is out of sync
- Set `concurrency.cancel-in-progress: true` for PRs, `false` for main — cancelling a main deploy mid-flight can leave infra in a broken state
- Cache `~/.npm` keyed on `package-lock.json` hash — cache is invalidated on dependency changes, hits on unchanged deps
- Use GitHub Environments for production deploys — enables required reviewers as a deployment gate
- Run lint and typecheck before tests — they're faster and catch the most common errors first
- Never put plaintext secrets in workflow files — use `${{ secrets.NAME }}` and set them in GitHub repository settings
