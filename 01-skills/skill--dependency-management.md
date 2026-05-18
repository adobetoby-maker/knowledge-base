# Skill: Dependency Management

## Overview
Unmaintained dependencies are a primary attack vector (supply chain attacks) and source of hidden technical debt. The discipline: audit for vulnerabilities in CI (fail builds on high/critical), automate update PRs (Renovate or Dependabot), and periodically remove unused packages to shrink the attack surface and bundle size.

## Implementation

### Automated Security Audit in CI
```yaml
# .github/workflows/ci.yml
- name: Security audit
  run: npm audit --audit-level=high
  # Fails CI on high or critical vulnerabilities
  # Does NOT fail on moderate/low — too many false positives
```

For packages that are dev-only (test tools, build tools) and never ship to production, the audit level can be relaxed:
```bash
npm audit --audit-level=critical --omit=dev
```

### Renovate Configuration (recommended over Dependabot)
```json
// renovate.json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:base"],
  "schedule": ["every weekend"],
  "automerge": false,
  "packageRules": [
    {
      "matchUpdateTypes": ["patch"],
      "matchPackagePatterns": ["*"],
      "automerge": true          // auto-merge patch updates if CI passes
    },
    {
      "matchPackageNames": ["next", "react", "react-dom"],
      "groupName": "React framework",  // batch related updates into one PR
      "schedule": ["on the first day of the month"]
    }
  ]
}
```

### Finding Unused Dependencies
```bash
npx depcheck
```
Output lists:
- Unused dependencies (safe to remove)
- Missing dependencies (used in code but not in package.json)
- Unlisted (used in package.json scripts but not importable)

Remove unused: `npm uninstall package-name` — do this quarterly.

### Bundle Size Analysis
Before adding a new package:
```bash
# Check the npm package page for bundle size stats
# Or use bundlephobia.com to see minified + gzipped size
npx bundlesize --files "dist/**/*.js" --max-size "200kb"
```

After adding:
```bash
npm run build && npx source-map-explorer dist/static/**/*.js
# Or: npx next-bundle-analyzer (for Next.js)
```

### Pinning Strategy
```json
// package.json
{
  "dependencies": {
    "stripe": "16.2.0",          // pin exact for financial/critical packages
    "next": "^15.3.0",           // accept patches for framework (Renovate keeps it updated)
    "react": "^19.0.0"
  },
  "devDependencies": {
    "typescript": "5.8.3",       // pin exact — compiler version changes can break builds
    "eslint": "^9.0.0"           // minor updates OK for linting tools
  }
}
```

## Key Rules
- Run `npm audit --audit-level=high` in CI and fail the build on high/critical findings — moderate/low generate too many false positives to be actionable
- Use Renovate (or Dependabot) for automated update PRs — manual dependency updates are consistently skipped
- Automerge patch-level updates only when CI is comprehensive; require human review for minor and major
- Run `depcheck` quarterly and remove unused packages — each unused package is attack surface
- Check bundle size before adding any new dependency — a 200KB utility that tree-shakes to 5KB is fine; a 200KB dependency that doesn't tree-shake is not
- Pin TypeScript and compiler/toolchain versions exactly — toolchain updates can silently change type-checking behavior
- For critical financial or auth libraries (stripe, jsonwebtoken), pin the exact version and update manually after reading the changelog
