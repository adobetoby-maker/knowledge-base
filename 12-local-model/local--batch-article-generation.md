# Local Model: Batch Article Generation

## When to Use Local Models for Articles

Use local models (Ollama) for:
- Bulk generation of 20+ articles in a single session
- Draft generation that will be reviewed before publishing
- Cost-sensitive content pipelines

Use cloud API (Haiku/Sonnet) for:
- High-quality final content that goes directly to production
- Time-sensitive generation (local models are 5-10x slower)
- Complex articles requiring cross-referencing capabilities

## Article Generation Pipeline

```typescript
// scripts/generate-articles.ts
import { Ollama } from 'ollama'
import * as fs from 'fs/promises'
import * as path from 'path'

const ollama = new Ollama({ host: 'http://localhost:11434' })
const MODEL = 'llama3.2'
const OUTPUT_DIR = './generated-articles'

interface ArticleBrief {
  slug: string
  title: string
  targetKeyword: string
  category: string
  wordCount: number
}

const ARTICLE_BRIEFS: ArticleBrief[] = [
  { slug: 'brake-fluid-flush-twin-falls', title: 'Brake Fluid Flush in Twin Falls', targetKeyword: 'brake fluid flush Twin Falls ID', category: 'maintenance', wordCount: 900 },
  { slug: 'transmission-service-magic-valley', title: 'Transmission Service in Magic Valley', targetKeyword: 'transmission service Magic Valley Idaho', category: 'repair', wordCount: 1000 },
  // ... more articles
]

const SYSTEM_PROMPT = `You are a content writer for Jr.'s Auto Repair in Twin Falls, Idaho.

Business context:
- Name: Jr.'s Auto Repair
- Owner: Pablo Zaldivar
- Address: 417 Main Ave E, Twin Falls, ID 83301
- Phone: (208) 595-2101
- Rating: 4.8 stars, 146 reviews
- Tagline: "Honest work, fair prices, done right the first time"
- Service area: Twin Falls and Magic Valley (50-mile radius)

Writing guidelines:
- Mention "Twin Falls" and "Magic Valley" together in every article
- Use the target keyword naturally 3-5 times
- Include one FAQ section with 4-6 Q&As
- Keep tone friendly but professional
- Include a call to action with the phone number
- Do NOT use markdown headers — use HTML: <h2>, <h3>
- Do NOT use markdown lists — use HTML: <ul><li>`

async function generateArticle(brief: ArticleBrief): Promise<string> {
  const prompt = `Write a ${brief.wordCount}-word article titled "${brief.title}".

Target keyword: "${brief.targetKeyword}"
Category: ${brief.category}

Return ONLY the article HTML body (no frontmatter, no explanations).
Start with an intro paragraph, use <h2> for main sections, include a FAQ section near the end, and end with a CTA paragraph.`

  const response = await ollama.chat({
    model: MODEL,
    messages: [
      { role: 'system', content: SYSTEM_PROMPT },
      { role: 'user', content: prompt },
    ],
    options: { temperature: 0.7, num_ctx: 4096 },
  })
  
  return response.message.content
}

async function runBatch() {
  await fs.mkdir(OUTPUT_DIR, { recursive: true })
  
  const progress = { completed: 0, failed: 0 }
  
  for (const brief of ARTICLE_BRIEFS) {
    const outputPath = path.join(OUTPUT_DIR, `${brief.slug}.html`)
    
    // Skip if already generated:
    try {
      await fs.access(outputPath)
      console.log(`[SKIP] ${brief.slug} — already exists`)
      continue
    } catch {}
    
    console.log(`[GENERATING] ${brief.slug}...`)
    
    try {
      const content = await generateArticle(brief)
      await fs.writeFile(outputPath, content, 'utf8')
      progress.completed++
      console.log(`[DONE] ${brief.slug} (${content.length} chars)`)
    } catch (error) {
      progress.failed++
      console.error(`[FAIL] ${brief.slug}: ${(error as Error).message}`)
    }
  }
  
  console.log(`\nCompleted: ${progress.completed}, Failed: ${progress.failed}`)
}

runBatch()
```

## Quality Review Before Import

After generation, review before importing to `lib/articles.ts`:

```typescript
// scripts/review-generated-articles.ts
import { articles as existingArticles } from '../lib/articles'

async function reviewGeneratedArticles(dir: string) {
  const files = await fs.readdir(dir)
  const issues: Record<string, string[]> = {}
  
  for (const file of files) {
    const slug = path.basename(file, '.html')
    const content = await fs.readFile(path.join(dir, file), 'utf8')
    const fileIssues: string[] = []
    
    // Word count check:
    const wordCount = content.split(/\s+/).length
    if (wordCount < 600) fileIssues.push(`Too short: ${wordCount} words`)
    
    // Check for FAQ section:
    if (!content.includes('FAQ') && !content.includes('Frequently Asked')) {
      fileIssues.push('Missing FAQ section')
    }
    
    // Check for phone number:
    if (!content.includes('(208) 595-2101')) {
      fileIssues.push('Missing phone number in CTA')
    }
    
    // Check for geo terms:
    if (!content.match(/twin falls/i)) fileIssues.push('Missing "Twin Falls"')
    if (!content.match(/magic valley/i)) fileIssues.push('Missing "Magic Valley"')
    
    if (fileIssues.length > 0) issues[slug] = fileIssues
  }
  
  Object.entries(issues).forEach(([slug, slugIssues]) => {
    console.log(`\n${slug}:`)
    slugIssues.forEach(i => console.log(`  ⚠ ${i}`))
  })
}
```

## Importing to lib/articles.ts

After review, convert HTML files to TypeScript array entries:

```typescript
// Each article becomes an entry in lib/articles.ts:
{
  slug: 'brake-fluid-flush-twin-falls',
  title: 'Brake Fluid Flush in Twin Falls',
  excerpt: 'Learn when to flush brake fluid and what to expect at Jr.\'s Auto Repair...',
  category: 'maintenance',
  date: '2025-09-15',
  readTime: 5,
  body: `...HTML content here...`,
}
```

Never import HTML files at runtime — embed the content as TypeScript string literals at build time.
