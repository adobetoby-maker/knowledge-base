# Principle: Dependency Health

## Overview
Every dependency is a liability you've agreed to maintain. Abandoned packages, single-maintainer projects, and packages with high CVE counts are time bombs — they don't fail immediately, but they accumulate risk that materializes as a forced emergency migration at the worst possible time. Proactive dependency health monitoring converts future emergencies into planned maintenance. The goal is to never be surprised by a dependency becoming untenable.

## Implementation

### Health Indicators to Monitor
```ts
interface DependencyHealth {
  name: string;
  version: string;

  // Activity signals
  lastCommitDaysAgo: number;       // > 730 = abandoned territory
  openIssues: number;
  openPRs: number;
  releasedDaysAgo: number;

  // Usage signals
  weeklyDownloads: number;         // < 10k = niche/risky
  githubStars: number;
  dependentPackages: number;

  // Security
  knownCVEs: number;

  // Maintenance
  maintainerCount: number;         // 1 = bus-factor-1 risk
  hasTypeScript: boolean;          // .d.ts files or TS source
  license: string;                 // MIT/Apache = good; GPL = check compliance

  riskScore: number;               // computed
}

function computeRiskScore(dep: Omit<DependencyHealth, 'riskScore'>): number {
  let risk = 0;

  if (dep.lastCommitDaysAgo > 730) risk += 40;
  else if (dep.lastCommitDaysAgo > 365) risk += 20;

  if (dep.weeklyDownloads < 10_000) risk += 20;
  else if (dep.weeklyDownloads < 100_000) risk += 10;

  if (dep.maintainerCount === 1) risk += 15;
  if (dep.knownCVEs > 0) risk += dep.knownCVEs * 15;
  if (!dep.hasTypeScript) risk += 10;

  return Math.min(risk, 100);
}
```

### Audit Commands
```bash
# Check for vulnerabilities
npm audit --audit-level=high

# Check outdated packages
npm outdated

# Check potentially unused dependencies
npx depcheck --json

# Check licenses (ensures all are permissive)
npx license-checker --onlyAllow 'MIT;Apache-2.0;BSD-2-Clause;BSD-3-Clause;ISC'
```

### Preferred Dependency Checklist
Before adding a new dependency, verify:

```
□ > 100k weekly npm downloads
□ Commits in the last 6 months (GitHub: check commit graph)
□ TypeScript types (first-party .ts or @types/ package)
□ MIT, Apache 2.0, or BSD license
□ Multiple maintainers (check npm page)
□ No critical CVEs in npm audit
□ README has usage examples and is maintained
□ Package size acceptable (bundlephobia.com for frontend deps)
□ Test suite exists (check package.json for "test" script)
```

### Migration Planning Before Forced Migration
```ts
// Document risk in a dependency registry file (dep-health.json)
const DEP_REGISTRY = {
  "moment": {
    status: "migration-planned",
    replacedBy: "date-fns",
    migrationTicket: "PLAT-1234",
    deadline: "2025-Q2",
    reason: "abandoned, large bundle, mutable API"
  },
  "lodash": {
    status: "monitoring",
    risk: "low",
    note: "large bundle — consider per-function imports or native alternatives"
  },
  "request": {
    status: "removed",
    removedIn: "v2.4.0",
    replacedBy: "fetch",
    reason: "deprecated since 2020"
  }
};
```

### Package Lifecycle Stages
```
Stage              Action
Healthy           Monitor quarterly; keep updated
Slow release      Monitor monthly; evaluate alternatives
No activity 6mo   Plan migration; create ticket
No activity 1yr   Prioritize migration; add to tech debt register
No activity 2yr+  Emergency classification; migrate before next major feature
CVE found         Block PR merges; patch or migrate immediately
Deprecated        Set migration deadline in current quarter
```

### Vulnerability Triage by Severity
```
Critical CVE:  Block CI, patch within 24 hours or remove dependency
High CVE:      Patch within 1 sprint; no new usage of affected dep
Moderate CVE:  Include in next planned update cycle
Low CVE:       Note in quarterly audit; update with other deps
```

### Common Migration Paths
```
moment.js      → date-fns (smaller, tree-shakeable, immutable)
lodash         → native Array/Object methods or individual lodash packages
request        → fetch (built-in), node-fetch, or axios
enzyme         → @testing-library/react
styled-components (if replacing) → Tailwind CSS or CSS Modules
uuid           → crypto.randomUUID() (built-in Node 14.17+)
```

## Key Rules
- Run `npm audit` in CI on every PR — don't let vulnerabilities accumulate unnoticed.
- Prefer packages with > 100k weekly downloads — niche packages have less community support and are more likely to be abandoned.
- Single-maintainer packages are bus-factor-1 — if that person disappears, you're maintaining a fork.
- Plan migrations before being forced — a dependency becoming deprecated should trigger a migration ticket, not an emergency sprint.
- License compliance is a legal concern, not just a preference — GPL in a commercial product may require open-sourcing your code.
- Package size matters for frontend dependencies — check bundlephobia.com before adding any new client-side package.
- Document all intentionally retained risky dependencies with rationale — this prevents the same "should we remove this?" conversation from happening every quarter.
