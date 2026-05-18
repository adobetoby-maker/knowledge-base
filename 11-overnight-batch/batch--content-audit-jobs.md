# Overnight Batch: Content Audit Jobs

## What Content Audits Do

Scan published content for quality issues, accuracy problems, and SEO gaps:
- Check articles have correct metadata (title, description, date)
- Detect outdated information (old prices, discontinued services)
- Find missing schema markup
- Check internal links are valid (not 404)
- Compare word count against target range
- Flag articles with thin content or duplicate sections

## Batch Content Audit Script

```typescript
// scripts/audit-articles.ts
import { articles } from '../lib/articles'
import Anthropic from '@anthropic-ai/sdk'
import fs from 'fs'

interface AuditResult {
  slug: string
  issues: string[]
  warnings: string[]
  score: number
}

const client = new Anthropic()

async function auditArticle(article: Article): Promise<AuditResult> {
  const issues: string[] = []
  const warnings: string[] = []
  
  // Structural checks — no AI needed:
  if (!article.title || article.title.length < 20) issues.push('Title too short')
  if (!article.excerpt || article.excerpt.length < 80) issues.push('Excerpt too short')
  if (!article.date) issues.push('Missing date')
  if (article.body.length < 500) issues.push('Body too short (< 500 chars)')
  if (article.body.length > 8000) warnings.push('Body very long — consider splitting')
  
  // Check for required local elements:
  if (!article.body.includes('(208)')) warnings.push('Missing phone number in body')
  if (!article.body.includes('Twin Falls')) warnings.push('Missing location mention')
  
  // AI quality check — only for structurally passing articles:
  if (issues.length === 0) {
    const response = await client.messages.create({
      model: 'claude-haiku-4-5',
      max_tokens: 200,
      messages: [{
        role: 'user',
        content: `Rate this auto repair article intro 0-10 for readability, customer focus, and local SEO. Reply JSON only: {"score": N, "feedback": "one sentence"}

Title: ${article.title}
Body: ${article.body.substring(0, 400)}`,
      }],
    })
    
    try {
      const ai = JSON.parse(response.content[0].text)
      if (ai.score < 6) warnings.push(`AI quality flag: ${ai.feedback}`)
      const score = Math.round((ai.score / 10) * 100)
      return { slug: article.slug, issues, warnings, score }
    } catch {
      // JSON parse failed — skip AI score
    }
  }
  
  const score = Math.max(0, 100 - issues.length * 20 - warnings.length * 10)
  return { slug: article.slug, issues, warnings, score }
}

async function main() {
  const results: AuditResult[] = []
  
  for (const article of articles) {
    console.log(`Auditing: ${article.slug}`)
    const result = await auditArticle(article)
    results.push(result)
    
    if (result.issues.length > 0) {
      console.log(`  ISSUES: ${result.issues.join(', ')}`)
    }
    
    await new Promise(r => setTimeout(r, 500))
  }
  
  const report = {
    auditedAt: new Date().toISOString(),
    total: results.length,
    healthy: results.filter(r => r.issues.length === 0 && r.warnings.length === 0).length,
    hasIssues: results.filter(r => r.issues.length > 0),
    hasWarnings: results.filter(r => r.warnings.length > 0 && r.issues.length === 0),
    averageScore: Math.round(results.reduce((s, r) => s + r.score, 0) / results.length),
  }
  
  fs.writeFileSync('audit-report.json', JSON.stringify(report, null, 2))
  console.log(`\nAudit complete. Average score: ${report.averageScore}/100`)
  console.log(`Articles with issues: ${report.hasIssues.length}`)
}

main()
```

## Internal Link Validation

```typescript
async function validateInternalLinks(articles: Article[]): Promise<void> {
  const slugs = new Set(articles.map(a => a.slug))
  const brokenLinks: { article: string; link: string }[] = []
  
  for (const article of articles) {
    const linkPattern = /href="\/blog\/([^"]+)"/g
    let match
    while ((match = linkPattern.exec(article.body)) !== null) {
      const linkedSlug = match[1]
      if (!slugs.has(linkedSlug)) {
        brokenLinks.push({ article: article.slug, link: `/blog/${linkedSlug}` })
      }
    }
  }
  
  if (brokenLinks.length > 0) {
    console.log('Broken internal links:')
    brokenLinks.forEach(({ article, link }) => {
      console.log(`  ${article} → ${link}`)
    })
  }
}
```

## Scheduling

Run weekly — not daily (content changes slowly):
```yaml
# .github/workflows/content-audit.yml
on:
  schedule:
    - cron: '0 7 * * 1'  # Monday 7am UTC
  workflow_dispatch:
```

## What to Do With Results

- **Issues (score < 60)**: Fix before next weekly run
- **Warnings (score 60-79)**: Queue for next content sprint
- **Healthy (score 80+)**: No action needed
