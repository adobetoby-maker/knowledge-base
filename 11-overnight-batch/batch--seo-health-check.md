# Batch: SEO Health Check

## Purpose

Run automated SEO checks on a schedule to catch issues that accumulate over time:
- Missing meta descriptions
- Duplicate titles
- Articles without FAQ schema
- Images without alt text
- Slug format violations

This is a structural check — it doesn't require AI inference.

## Article SEO Validator

```typescript
// scripts/seo-health-check.ts
import { articles } from '../lib/articles'
import type { Article } from '../lib/articles'

interface SEOIssue {
  slug: string
  issues: string[]
}

function checkArticle(article: Article): string[] {
  const issues: string[] = []
  
  // Title checks:
  if (article.title.length < 20) issues.push(`Title too short (${article.title.length} chars, min 20)`)
  if (article.title.length > 65) issues.push(`Title too long (${article.title.length} chars, max 65)`)
  if (!article.title.match(/twin falls|magic valley|idaho/i)) issues.push('Title missing geo-modifier (Twin Falls / Magic Valley / Idaho)')
  
  // Excerpt / meta description:
  if (!article.excerpt) issues.push('Missing excerpt (used as meta description)')
  else if (article.excerpt.length < 80) issues.push(`Excerpt too short (${article.excerpt.length} chars, min 80)`)
  else if (article.excerpt.length > 160) issues.push(`Excerpt too long (${article.excerpt.length} chars, max 160)`)
  
  // Slug format:
  if (!article.slug.match(/^[a-z0-9-]+$/)) issues.push('Slug contains invalid characters (use lowercase, numbers, hyphens only)')
  if (article.slug.includes('--')) issues.push('Slug has double hyphens')
  
  // Body checks:
  if (article.body.length < 500) issues.push(`Body too short (${article.body.length} chars, min 500)`)
  
  // Check for h1 in body (there should be none — title IS the h1):
  if (article.body.match(/<h1/i)) issues.push('Body contains h1 — remove it (the page title is the h1)')
  
  // Check for images without alt:
  const imgWithoutAlt = article.body.match(/<img(?![^>]*alt=)[^>]*>/gi)
  if (imgWithoutAlt) issues.push(`${imgWithoutAlt.length} image(s) missing alt attribute`)
  
  // Check readTime is set and reasonable:
  if (!article.readTime) issues.push('Missing readTime')
  else {
    const estimatedReadTime = Math.ceil(article.body.split(' ').length / 200)
    if (Math.abs(estimatedReadTime - article.readTime) > 3) {
      issues.push(`readTime (${article.readTime}m) doesn't match word count (~${estimatedReadTime}m)`)
    }
  }
  
  return issues
}

async function runSEOHealthCheck() {
  const allIssues: SEOIssue[] = []
  
  // Check for duplicate titles:
  const titleMap = new Map<string, string[]>()
  articles.forEach(a => {
    const normalized = a.title.toLowerCase()
    titleMap.set(normalized, [...(titleMap.get(normalized) ?? []), a.slug])
  })
  titleMap.forEach((slugs, title) => {
    if (slugs.length > 1) {
      slugs.forEach(slug => {
        allIssues.push({ slug, issues: [`Duplicate title: "${title}" also used by ${slugs.filter(s => s !== slug).join(', ')}`] })
      })
    }
  })
  
  // Check each article:
  articles.forEach(article => {
    const issues = checkArticle(article)
    if (issues.length > 0) {
      allIssues.push({ slug: article.slug, issues })
    }
  })
  
  // Report:
  if (allIssues.length === 0) {
    console.log(`✓ All ${articles.length} articles pass SEO health check`)
    return
  }
  
  console.log(`\nSEO Issues Found: ${allIssues.length} articles\n`)
  allIssues.forEach(({ slug, issues }) => {
    console.log(`  /blog/${slug}`)
    issues.forEach(issue => console.log(`    ⚠ ${issue}`))
  })
  
  // Exit 0 even with issues — this is advisory, not a build-breaking check
}

runSEOHealthCheck()
```

## Package Script

```json
{
  "scripts": {
    "seo:check": "npx tsx scripts/seo-health-check.ts"
  }
}
```

## Scheduled Run

```yaml
# .github/workflows/seo-check.yml
name: SEO Health Check
on:
  schedule:
    - cron: '0 7 * * 1'  # Mondays 7 AM
  push:
    paths: ['lib/articles.ts']

jobs:
  seo-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22' }
      - run: npm ci
      - run: npm run seo:check
```

## What to Do with Results

Priority order for fixes:
1. Missing excerpts → add immediately (affects meta descriptions)
2. Titles too long → shorten (truncated in SERPs)
3. Duplicate titles → differentiate (Google may choose one to rank)
4. Images missing alt → add descriptive alt text
5. Too-short articles → expand or merge with a related article
