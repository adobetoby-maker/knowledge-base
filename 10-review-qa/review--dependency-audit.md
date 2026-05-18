# Review: Dependency Audit Checklist

## Overview
Dependencies are the most common vector for security vulnerabilities, unexpected breakage, and license
violations in production software. Most teams review application code carefully but add npm packages
without the same scrutiny. This checklist treats each dependency addition as a decision with long-term
maintenance implications.

## Implementation

### Abandoned Package Detection
```bash
# Check last commit date on GitHub or npm
npm info <package> time.modified   # last publish date

# Red flags:
# - Last publish > 2 years ago AND no "deprecated" notice (maintainer may have abandoned it)
# - Zero recent issues being addressed
# - No release notes for the last 12 months

# Check for an actively maintained fork or built-in alternative first
```

### Known CVEs (npm audit)
```bash
npm audit                         # report all vulnerabilities
npm audit --audit-level=high      # CI gate — fail on high+ severity

# Fix automatically where possible
npm audit fix
npm audit fix --force             # upgrades major versions — test carefully

# Suppress a false positive (document why)
# In package.json:
"overrides": {
  "vulnerable-transitive-dep": ">=2.0.0"
}
```
```bash
# For more comprehensive scanning:
npx snyk test                     # checks Snyk database (broader than npm audit)
trivy fs .                        # scans node_modules for CVEs using multiple databases
```

### License Compatibility
```
SAFE for SaaS/commercial products:
  MIT, BSD-2, BSD-3, Apache-2.0, ISC — permissive, no copyleft

REQUIRES REVIEW:
  LGPL — library can be used in proprietary code IF not modified; linking rules apply
  CC BY — requires attribution in product

PROBLEMATIC for SaaS:
  GPL v2/v3 — if you distribute software using GPL code, your software must also be GPL
  AGPL — extends GPL to network use; using AGPL in a SaaS means your source must be open

✗ NEVER include in commercial SaaS without legal review:
  GPL, AGPL, SSPL (Server Side Public License — MongoDB's license)
```
```bash
npx license-checker --summary     # list all dependency licenses
npx license-checker --onlyAllow 'MIT;Apache-2.0;BSD-2-Clause;BSD-3-Clause;ISC'  # strict allowlist
```

### Duplicate Package Versions
```bash
npm dedupe                        # attempt to flatten duplicate versions
npm ls <package-name>             # see all installed versions of a package

# Check bundle for duplicates
npx duplicate-package-checker-webpack-plugin  # Webpack
# Or inspect the Vite/Rollup bundle visualizer output
```
Duplicate React versions are especially problematic — hooks break when React is loaded twice.
```bash
# Check for duplicate React
npm ls react   # should show exactly one version
```

### Bundle Impact Assessment
```bash
# Before adding any package > 10kB:
# Check bundlephobia.com for bundle size and tree-shaking support

# Key metrics:
# - Min+gzip size
# - Tree-shakeable? (can you import only what you use)
# - Side effects? (can Rollup/webpack eliminate unused code)

# Example: lodash vs lodash-es
# lodash: 71kB min+gzip, NOT tree-shakeable by default
# lodash-es: tree-shakeable, import { debounce } ships only ~2kB
```

### Dependency Justification Review
```
For each new dependency in a PR, ask:
1. What does it replace? (was it already done by an existing dep?)
2. What is the bundle cost? (check bundlephobia)
3. Is it actively maintained? (last commit, open issues)
4. Is there a built-in alternative? (e.g., use native fetch instead of axios for simple cases)
5. Is it the most popular solution for this problem? (avoids obscure packages)
6. Does it have TypeScript types? (or would require @types/ companion)
```

## Key Rules
- Any package not updated in 2+ years needs explicit justification for inclusion — "it still works" is not sufficient
- Run `npm audit --audit-level=high` in CI and fail the build on high-severity findings
- GPL and AGPL licenses require legal review before use in commercial/SaaS products — document the decision
- Check for duplicate versions of React, React-DOM, and any state management library — duplicates cause runtime failures
- Prefer native Web APIs or built-in framework utilities over packages for simple operations (native fetch, crypto, URL)
- Use `npm ls <package>` to verify no duplicate major versions of critical packages
- `package-lock.json` must be committed — it locks transitive dependency versions and prevents supply chain substitution attacks
