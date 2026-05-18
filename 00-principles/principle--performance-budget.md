# Performance Budget

## What Is a Performance Budget

A performance budget sets hard limits on performance metrics BEFORE building a feature. Instead of optimizing after the fact, you design within constraints from the start.

## Budgets for This Stack

| Metric | Budget | Why |
|---|---|---|
| LCP | < 2.5s | Google CWV threshold for "Good" |
| INP | < 200ms | Google CWV threshold |
| CLS | < 0.1 | Google CWV threshold |
| Total JS (initial) | < 200KB gzipped | Keeps TTI low on 4G |
| Time to Interactive | < 3.5s on mobile 4G | User abandonment threshold |
| Lighthouse performance | > 85 | Practical floor for SEO + UX |

## Checking Budgets

```bash
# Lighthouse in terminal
npx lighthouse https://jrsautorepair.worker-bee.app \
  --output=json \
  --only-categories=performance \
  --quiet | jq '.categories.performance.score * 100'

# Bundle size
ANALYZE=true npm run build
# Check the .next/analyze/ output for bundle treemap
```

## When to Measure

Measure BEFORE starting a feature that could affect performance:
1. Run Lighthouse on current production
2. Note the current scores as baseline
3. After the feature ships, re-run
4. If any metric regressed past the budget, fix it before the next feature

Don't defer performance work — it compounds.

## JavaScript Budget Decisions

When adding a new npm package, estimate its bundle cost:
```bash
# Check package size before installing
npx bundlephobia <package-name>
```

| Decision | Budget Impact |
|---|---|
| Replace moment.js with date-fns | Save ~66KB |
| Add chart.js | +40KB — lazy-load it |
| Add lodash (full) | +24KB — use lodash-es + tree shaking instead |
| Add framer-motion | +50KB — only load on pages that animate |

Heavy libraries should be lazy-loaded with `next/dynamic` to the routes that need them.

## Image Budget

| Image Type | Max Size |
|---|---|
| Hero image | < 200KB |
| Product/service image | < 100KB |
| Thumbnail | < 30KB |
| OG image | < 300KB |

## Budget Enforcement in CI

```yaml
# .github/workflows/performance.yml
- name: Lighthouse CI
  run: |
    npx lhci autorun
  env:
    LHCI_GITHUB_APP_TOKEN: ${{ secrets.LHCI_GITHUB_APP_TOKEN }}
```

```json
// lighthouserc.json
{
  "ci": {
    "assert": {
      "assertions": {
        "categories:performance": ["warn", { "minScore": 0.85 }],
        "first-contentful-paint": ["error", { "maxNumericValue": 2000 }],
        "largest-contentful-paint": ["error", { "maxNumericValue": 2500 }],
        "cumulative-layout-shift": ["error", { "maxNumericValue": 0.1 }]
      }
    }
  }
}
```

## Performance Regressions

When a deployment causes a performance regression:
1. Run `git bisect` to identify the commit that caused it
2. Check the bundle analyzer for what grew
3. Common culprits:
   - New import added inside a component (should be in a separate lazy chunk)
   - `next/image` `priority` added to wrong image (should be LCP only)
   - New third-party script loaded synchronously
   - Large JSON data embedded in server component HTML

## Mobile Performance

Lighthouse defaults to simulated mobile 4G (10ms RTT, 1.6Mbps download). This is intentionally pessimistic — real users are often faster, but many are slower.

For local service businesses (jrs-auto-repair), target mobile users visiting from their phone at the shop or on the road. Mobile budget is MORE important than desktop.
