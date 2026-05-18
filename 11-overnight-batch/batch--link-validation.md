# Batch: Link Validation

## Purpose

Broken internal links hurt both UX and SEO. Run link validation on a schedule to catch:
- Links to pages that no longer exist
- Internal links pointing to wrong slugs after article renames
- External links that return 404 or have gone offline

## Internal Link Checker (TypeScript)

```typescript
// scripts/check-links.ts
import { articles } from '../lib/articles'
import { services } from '../lib/services'

interface LinkCheckResult {
  source: string
  brokenLinks: string[]
}

function buildValidPaths(): Set<string> {
  const paths = new Set<string>()
  paths.add('/')
  paths.add('/about')
  paths.add('/contact')
  paths.add('/blog')
  paths.add('/services')
  
  articles.forEach(a => paths.add(`/blog/${a.slug}`))
  services.forEach(s => paths.add(`/services/${s.slug}`))
  
  return paths
}

function extractLinks(html: string): string[] {
  const hrefs: string[] = []
  const regex = /href="([^"]+)"/g
  let match
  while ((match = regex.exec(html)) !== null) {
    hrefs.push(match[1])
  }
  return hrefs
}

async function checkInternalLinks(): Promise<LinkCheckResult[]> {
  const validPaths = buildValidPaths()
  const results: LinkCheckResult[] = []
  
  for (const article of articles) {
    const links = extractLinks(article.body)
    const internalLinks = links.filter(l => l.startsWith('/'))
    const broken = internalLinks.filter(l => !validPaths.has(l))
    
    if (broken.length > 0) {
      results.push({ source: `/blog/${article.slug}`, brokenLinks: broken })
    }
  }
  
  return results
}

checkInternalLinks().then(results => {
  if (results.length === 0) {
    console.log('All internal links valid.')
    process.exit(0)
  }
  
  console.log(`Found ${results.length} pages with broken links:`)
  results.forEach(r => {
    console.log(`  ${r.source}: ${r.brokenLinks.join(', ')}`)
  })
  process.exit(1)
})
```

## External Link Checker

Check that external links haven't gone 404 (run weekly, not on every build):

```typescript
// scripts/check-external-links.ts
const TIMEOUT_MS = 10000
const CONCURRENT = 5

async function checkUrl(url: string): Promise<'ok' | 'error' | 'timeout'> {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS)
  
  try {
    const resp = await fetch(url, {
      method: 'HEAD',
      signal: controller.signal,
      headers: { 'User-Agent': 'Link-Checker/1.0' },
    })
    clearTimeout(timeout)
    return resp.ok ? 'ok' : 'error'
  } catch {
    clearTimeout(timeout)
    return 'timeout'
  }
}

async function checkBatch(urls: string[]): Promise<Map<string, 'ok' | 'error' | 'timeout'>> {
  const results = new Map<string, 'ok' | 'error' | 'timeout'>()
  
  for (let i = 0; i < urls.length; i += CONCURRENT) {
    const batch = urls.slice(i, i + CONCURRENT)
    const checks = await Promise.all(
      batch.map(async url => ({ url, status: await checkUrl(url) }))
    )
    checks.forEach(({ url, status }) => results.set(url, status))
    console.log(`Checked ${Math.min(i + CONCURRENT, urls.length)} / ${urls.length}`)
  }
  
  return results
}
```

## GitHub Actions Workflow

Run internal link check on every PR, external link check weekly:

```yaml
# .github/workflows/link-check.yml
name: Link Check

on:
  pull_request:
    paths: ['lib/articles.ts', 'lib/services.ts']
  schedule:
    - cron: '0 6 * * 1'  # Mondays at 6 AM

jobs:
  internal-links:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22' }
      - run: npm ci
      - run: npx tsx scripts/check-links.ts
```

## Interpreting Results

External links failing:
- 404: article moved or deleted → update or remove the link
- 403: server blocking bots → HEAD request blocked, not actually broken (verify manually)
- Timeout: slow server → retry once before marking as broken

Internal links failing:
- Article slug changed → update all referencing articles
- Route removed → update to closest valid path

## Fixing Broken Links

After finding broken internal links, fix them in the article body strings:

```typescript
// In lib/articles.ts, find all href="/old-slug" and update:
// grep -n 'old-slug' lib/articles.ts
// Then edit each occurrence
```

For large articles, run a Node script that replaces the old slug across all articles programmatically.
