# Batch: Performance Monitoring Jobs

## What This Solves

Performance regressions happen gradually — a new component, a heavier image, a slower query. Overnight performance monitoring catches regressions before users notice, and trends over time are more useful than spot-check readings.

## Lighthouse CI (Automated Nightly)

```yaml
# .github/workflows/lighthouse.yml
name: Lighthouse Performance Audit

on:
  schedule:
    - cron: '0 3 * * *'  # 3 AM daily
  workflow_dispatch:

jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Lighthouse CI
        uses: treosh/lighthouse-ci-action@v11
        with:
          urls: |
            https://jrsautorepair.com/
            https://jrsautorepair.com/services/brake-repair
            https://jrsautorepair.com/blog
          budgetPath: './lighthouse-budget.json'
          uploadArtifacts: true
          temporaryPublicStorage: true
```

Budget file:
```json
// lighthouse-budget.json
[
  {
    "path": "/*",
    "timings": [
      { "metric": "interactive", "budget": 3000 },
      { "metric": "first-contentful-paint", "budget": 1500 },
      { "metric": "largest-contentful-paint", "budget": 2500 }
    ],
    "resourceSizes": [
      { "resourceType": "script", "budget": 150 },
      { "resourceType": "total", "budget": 400 }
    ],
    "scores": [
      { "category": "performance", "minScore": 85 },
      { "category": "accessibility", "minScore": 90 },
      { "category": "seo", "minScore": 90 }
    ]
  }
]
```

## Core Web Vitals Script

```ts
// scripts/check-cwv.ts
// Uses PageSpeed Insights API to get field data

const API_KEY = process.env.GOOGLE_PAGESPEED_API_KEY!

interface CWVResult {
  url: string
  lcp: number      // ms
  inp: number      // ms
  cls: number
  rating: 'GOOD' | 'NEEDS_IMPROVEMENT' | 'POOR'
}

async function getCWV(url: string): Promise<CWVResult | null> {
  const endpoint = `https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=${encodeURIComponent(url)}&strategy=mobile&key=${API_KEY}`
  const res = await fetch(endpoint)
  const data = await res.json()

  const metrics = data.loadingExperience?.metrics
  if (!metrics) return null

  return {
    url,
    lcp: metrics.LARGEST_CONTENTFUL_PAINT_MS?.percentile ?? 0,
    inp: metrics.INTERACTION_TO_NEXT_PAINT?.percentile ?? 0,
    cls: metrics.CUMULATIVE_LAYOUT_SHIFT_SCORE?.percentile ?? 0,
    rating: data.loadingExperience?.overall_category,
  }
}

const PAGES_TO_CHECK = [
  'https://jrsautorepair.com/',
  'https://jrsautorepair.com/services/brakes',
]

async function main() {
  const results = await Promise.all(PAGES_TO_CHECK.map(getCWV))

  for (const result of results) {
    if (!result) continue

    const status = result.rating === 'GOOD' ? '✓' : '✗'
    console.log(`${status} ${result.url}`)
    console.log(`  LCP: ${result.lcp}ms | INP: ${result.inp}ms | CLS: ${result.cls}`)

    // Alert if any metric is poor
    if (result.rating === 'POOR') {
      await sendSlackAlert(`Performance alert: ${result.url} is rated POOR`)
    }
  }

  // Store historical data
  await supabaseAdmin.from('performance_history').insert(
    results.filter(Boolean).map(r => ({
      url: r!.url,
      lcp_ms: r!.lcp,
      inp_ms: r!.inp,
      cls: r!.cls,
      measured_at: new Date().toISOString(),
    }))
  )
}
```

## Bundle Size Tracking

```ts
// scripts/check-bundle-size.ts
import * as fs from 'fs'
import * as path from 'path'

const BUILD_MANIFEST = '.next/build-manifest.json'
const SIZE_BUDGET_BYTES = 150 * 1024  // 150KB

async function checkBundleSize() {
  const manifest = JSON.parse(fs.readFileSync(BUILD_MANIFEST, 'utf-8'))

  let totalJsBytes = 0
  const oversized: string[] = []

  for (const [page, chunks] of Object.entries(manifest.pages)) {
    for (const chunk of chunks as string[]) {
      const filePath = path.join('.next', 'static', chunk)
      if (!fs.existsSync(filePath)) continue

      const size = fs.statSync(filePath).size
      totalJsBytes += size

      if (size > SIZE_BUDGET_BYTES) {
        oversized.push(`${chunk}: ${(size / 1024).toFixed(1)}KB`)
      }
    }
  }

  if (oversized.length > 0) {
    console.warn('Oversized chunks:')
    oversized.forEach(c => console.warn(' ', c))
    process.exit(1)  // Fail CI
  }

  console.log(`Total JS: ${(totalJsBytes / 1024).toFixed(1)}KB ✓`)
}
```

## Query Performance Monitoring

```ts
// scripts/slow-query-report.ts
// Finds queries that took > 100ms in the last 24 hours

const { data: slowQueries } = await supabaseAdmin.rpc('get_slow_queries', {
  min_duration_ms: 100,
  hours_back: 24,
})

// Or use Supabase MCP: get_advisors for performance recommendations
```

Use Supabase's built-in Performance Advisor:
```
mcp__plugin_supabase_supabase__get_advisors({
  projectId: PROJECT_ID,
  type: 'performance',
})
```

## Trend Alerting

```ts
// Alert if today's score is significantly worse than 7-day average
const { data: history } = await supabaseAdmin
  .from('performance_history')
  .select('lcp_ms, measured_at')
  .eq('url', url)
  .order('measured_at', { ascending: false })
  .limit(8)

const [today, ...previous] = history ?? []
const avgPrevious = previous.reduce((s, r) => s + r.lcp_ms, 0) / previous.length

if (today.lcp_ms > avgPrevious * 1.3) {
  await alert(`LCP regression on ${url}: ${today.lcp_ms}ms vs ${avgPrevious.toFixed(0)}ms 7-day avg`)
}
```
