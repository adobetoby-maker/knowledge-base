# Overnight Content Generation Jobs

## What Qualifies as a Batch Job

Content generation tasks are ideal for overnight batch processing when:
- Task requires many similar items (20+ articles, hundreds of descriptions)
- Each item is independent (can run in parallel or serial without coordination)
- Human review happens AFTER generation, not during
- Failure of one item should not stop the batch

## Job Structure

Every batch job file requires five elements:

1. **Input** — explicit list or query defining what to generate
2. **Output schema** — TypeScript type or Zod schema for each item
3. **Prompt template** — parameterized template, not ad hoc strings
4. **Error handling** — catch per-item, never throw the whole batch
5. **Progress tracking** — write to file so incomplete batch is resumable

## Article Generation Job

```typescript
// scripts/generate-articles.ts
import Anthropic from '@anthropic-ai/sdk'
import { z } from 'zod'
import { writeFileSync, readFileSync, existsSync } from 'fs'
import { articles as existingArticles } from '../lib/articles'

const client = new Anthropic()

const articleOutputSchema = z.object({
  slug: z.string(),
  title: z.string(),
  excerpt: z.string().max(160),
  body: z.string().min(800),
  category: z.enum(['maintenance', 'repair', 'seasonal', 'how-to', 'local']),
  readTime: z.number(),
})

const TOPICS: string[] = [
  'how often to change brake fluid in Idaho winter conditions',
  'signs your car battery is dying before winter',
  'tire rotation benefits for Twin Falls roads',
  // ... add more
]

const PROGRESS_FILE = '/tmp/article-gen-progress.json'

async function generateArticle(topic: string): Promise<z.infer<typeof articleOutputSchema> | null> {
  try {
    const message = await client.messages.create({
      model: 'claude-haiku-4-5',
      max_tokens: 2000,
      messages: [{
        role: 'user',
        content: `Write a blog article for Jr.'s Auto Repair in Twin Falls, Idaho about: "${topic}"

Return ONLY valid JSON matching this exact schema:
{
  "slug": "url-safe-slug",
  "title": "Article Title (50-60 chars)",
  "excerpt": "Meta description (150-160 chars)",
  "body": "Full article in markdown (800-1000 words)",
  "category": "maintenance|repair|seasonal|how-to|local",
  "readTime": 5
}

Voice: Friendly, knowledgeable, like a trusted mechanic neighbor.
Include Twin Falls and/or Magic Valley naturally in the content.
Target keyword: include "${topic.split(' ').slice(0, 4).join(' ')}" in title and first paragraph.`,
      }],
    })
    
    const text = message.content[0].type === 'text' ? message.content[0].text : ''
    const jsonMatch = text.match(/\{[\s\S]*\}/)
    if (!jsonMatch) throw new Error('No JSON in response')
    
    const parsed = JSON.parse(jsonMatch[0])
    return articleOutputSchema.parse(parsed)
  } catch (err) {
    console.error(`FAILED: ${topic} — ${(err as Error).message}`)
    return null  // never throw — let batch continue
  }
}

async function runBatch() {
  // Load progress (resumable)
  const progress: string[] = existsSync(PROGRESS_FILE)
    ? JSON.parse(readFileSync(PROGRESS_FILE, 'utf-8'))
    : []
  
  const existingSlugs = new Set(existingArticles.map(a => a.slug))
  const results: Array<z.infer<typeof articleOutputSchema>> = []
  
  for (const topic of TOPICS) {
    if (progress.includes(topic)) {
      console.log(`SKIP (already done): ${topic}`)
      continue
    }
    
    console.log(`Generating: ${topic}`)
    const article = await generateArticle(topic)
    
    if (article && !existingSlugs.has(article.slug)) {
      results.push(article)
      existingSlugs.add(article.slug)
    }
    
    // Mark progress
    progress.push(topic)
    writeFileSync(PROGRESS_FILE, JSON.stringify(progress))
    
    // Rate limit: 1 request per second (Haiku tier)
    await new Promise(r => setTimeout(r, 1000))
  }
  
  // Write output
  writeFileSync(
    '/tmp/generated-articles.json',
    JSON.stringify(results, null, 2)
  )
  
  console.log(`Done: ${results.length} articles generated`)
}

runBatch().catch(console.error)
```

## Running the Job

```bash
# From project root
npx ts-node scripts/generate-articles.ts

# Or in background (overnight)
nohup npx ts-node scripts/generate-articles.ts > /tmp/article-gen.log 2>&1 &
echo $! > /tmp/article-gen.pid

# Monitor progress
tail -f /tmp/article-gen.log

# Stop
kill $(cat /tmp/article-gen.pid)
```

## After the Job: Human Review Step

Generated content requires human review before publishing. The job produces a JSON file — a human (or review agent) reads it and approves/rejects items.

Review agent prompt:
```
Review the articles in /tmp/generated-articles.json for:
1. Factual accuracy (no claims that could be verified as wrong)
2. Duplicate content (similar to existing articles in lib/articles.ts)
3. Tone consistency (friendly/knowledgeable, not salesy)
4. Local relevance (mentions Twin Falls or Magic Valley naturally)

For each article: APPROVE, REVISE (note what to fix), or REJECT (note why).
Output the approved articles as a JSON array ready to append to lib/articles.ts.
```

## Rate Limits to Respect

| Model | Rate limit (approximate) | Max parallel requests |
|-------|--------------------------|----------------------|
| claude-haiku-4-5 | 100K tokens/min | 5-10 |
| claude-sonnet-4-6 | 40K tokens/min | 2-3 |

For overnight jobs, be conservative — use 1 second between Haiku requests, 3 seconds between Sonnet.
