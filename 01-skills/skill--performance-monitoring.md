# Skill: Web Performance Monitoring

## Overview
Performance degrades silently — a slow database query, a large image, a third-party script bloat — and users leave before anyone notices. Real User Monitoring (RUM) captures what actual users experience on real devices and networks. Synthetic monitoring (Lighthouse CI) catches regressions before they ship. Both are necessary: synthetic for prevention, RUM for truth.

## RUM vs Synthetic

| | Real User Monitoring (RUM) | Synthetic |
|---|---|---|
| What | Metrics from real browsers in production | Simulated in controlled lab environment |
| When | Continuous, on every page visit | On demand, on every CI build |
| Strength | Real network, real devices, real paths | Repeatable, catches regressions before prod |
| Tool examples | `web-vitals` library, Datadog RUM, SpeedCurve | Lighthouse CI, WebPageTest |

## Core Web Vitals Collection

```ts
// In _app.tsx or root layout — runs in browser only
import { onCLS, onFID, onFCP, onLCP, onTTFB, onINP } from 'web-vitals'

type Metric = { name: string; value: number; rating: 'good' | 'needs-improvement' | 'poor' }

function sendToAnalytics({ name, value, rating }: Metric) {
  // Send on next idle, not blocking render
  if ('sendBeacon' in navigator) {
    navigator.sendBeacon('/api/vitals', JSON.stringify({ name, value, rating, url: location.href }))
  }
}

onCLS(sendToAnalytics)   // Cumulative Layout Shift — < 0.1 good
onLCP(sendToAnalytics)   // Largest Contentful Paint — < 2.5s good
onINP(sendToAnalytics)   // Interaction to Next Paint — < 200ms good (replaced FID)
onFCP(sendToAnalytics)
onTTFB(sendToAnalytics)
```

## Sending Metrics on Page Unload

```ts
// Use visibilitychange — pagehide is unreliable on mobile
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'hidden') {
    // Flush buffered metrics
    flushMetrics()
  }
})

// Never use unload — it prevents bfcache and is unreliable
// Never use beforeunload for analytics — blocks page exit
```

## Lighthouse CI in GitHub Actions

```yaml
# .github/workflows/lighthouse.yml
- name: Lighthouse CI
  uses: treosh/lighthouse-ci-action@v12
  with:
    urls: |
      http://localhost:3000/
      http://localhost:3000/pricing
    budgetPath: .lighthouserc.json
    uploadArtifacts: true
```

```json
// .lighthouserc.json
{
  "ci": {
    "assert": {
      "assertions": {
        "categories:performance": ["error", { "minScore": 0.9 }],
        "categories:accessibility": ["error", { "minScore": 0.95 }],
        "categories:best-practices": ["warn", { "minScore": 0.9 }],
        "categories:seo": ["warn", { "minScore": 0.9 }]
      }
    }
  }
}
```

Fail CI if performance score drops below 90. Run against production-like build (not dev mode — dev mode has intentional slowness).

## PerformanceObserver for Long Tasks

Long tasks (> 50ms) block the main thread and degrade INP. Track them:

```ts
if ('PerformanceObserver' in window) {
  const observer = new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
      if (entry.duration > 50) {
        console.warn('Long task detected:', entry.duration, entry)
        sendToAnalytics({ name: 'longtask', value: entry.duration, rating: 'poor' })
      }
    }
  })
  observer.observe({ entryTypes: ['longtask'] })
}
```

## Resource Timing for Third-Party Scripts

```ts
const observer = new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) {
    const resource = entry as PerformanceResourceTiming
    if (resource.duration > 500) {
      console.warn('Slow resource:', resource.name, resource.duration)
    }
  }
})
observer.observe({ entryTypes: ['resource'] })
```

## Key Rules
- Never send metrics with synchronous XHR — use `sendBeacon` for reliability
- Use `visibilitychange` + `hidden` state to flush metrics, not `unload`
- Lighthouse scores are lab scores — RUM scores will differ (mobile, slow networks)
- Run Lighthouse in CI against a built + served app, never `next dev`
- Set a performance budget and break the build when it's violated — alerts without gates don't work
- Track LCP element — use `PerformanceObserver` with `largest-contentful-paint` entry type
- INP replaced FID as Core Web Vital in March 2024 — update any old tooling
