# Local Model Batching Strategy

## Why Batch with Local Models

Overnight batch sessions with local models (Ollama) can process large amounts of mechanical work while sleeping:
- Generating blog articles across multiple sites
- Creating SEO content variants
- Writing unit tests for existing functions
- Renaming/refactoring across files
- Generating TypeScript types from database schemas

The key constraint: local models are less accurate and less capable than Claude. Tasks must be structured so failures are safe and detectable.

## Task Selection Criteria

**Good for local model batch:**
- Clear input → deterministic output mapping
- Output can be validated (build still passes, TypeScript still types, tests still run)
- Failure leaves the codebase in a recoverable state (no deletions, no migrations)
- Volume justifies setup time (10+ repetitive tasks)

**Bad for local model batch:**
- Architectural decisions
- Auth or security logic
- Database migrations
- Anything where "close but wrong" breaks production

## Batch Structure

Each batch job needs:

```
1. Task list — explicit array of inputs, one per operation
2. Constraints — what the model must NOT do
3. Output template — exact format to fill in
4. Validation step — how to verify success
5. Failure sink — where to log operations that fail
```

## Task List Format

```json
[
  {
    "id": "article-001",
    "type": "seo-article",
    "input": {
      "slug": "brake-pads-twin-falls",
      "title": "Brake Pad Replacement in Twin Falls ID",
      "keyword": "brake pads Twin Falls",
      "wordCount": 800
    },
    "output_path": "/tmp/articles/brake-pads-twin-falls.json"
  },
  ...
]
```

## Prompt Template for Batch Article Generation

```
You are writing SEO articles for Jr.'s Auto Repair in Twin Falls, Idaho.

ARTICLE SPECIFICATION:
Slug: {slug}
Title: {title}
Target keyword: {keyword}
Word count: {wordCount}

RULES:
- The keyword must appear in: title, first paragraph, at least one H2, and organically in body
- Include local references to Twin Falls and Magic Valley
- Phone: (208) 595-2101
- Tone: knowledgeable, direct, friendly (not corporate)
- Do NOT include markdown code blocks
- Do NOT add metadata headers

OUTPUT FORMAT — respond with ONLY valid JSON, nothing else:
{
  "slug": "{slug}",
  "title": "{title}",
  "excerpt": "[150-160 char excerpt with keyword]",
  "body": "[full article body in markdown, no code blocks]"
}
```

## Validation Script

After each batch run:

```typescript
// scripts/validate-batch-articles.ts
import { articles } from '../lib/articles'

const required = ['slug', 'title', 'excerpt', 'body']

for (const article of batchOutput) {
  for (const field of required) {
    if (!article[field]) {
      console.error(`MISSING FIELD: ${field} in ${article.slug}`)
    }
  }
  
  if (article.excerpt.length > 160) {
    console.warn(`EXCERPT TOO LONG: ${article.slug} (${article.excerpt.length} chars)`)
  }
  
  if (!article.body.includes(article.keyword)) {
    console.warn(`KEYWORD MISSING: ${article.slug}`)
  }
}
```

## Failure Handling in Batch

Local models produce malformed JSON, empty outputs, or hallucinated content more often than Claude. Batch scripts must handle failures gracefully:

```typescript
async function processTask(task: BatchTask): Promise<void> {
  try {
    const response = await ollama.generate(buildPrompt(task))
    const parsed = JSON.parse(response.text)
    
    if (!isValid(parsed)) {
      await logFailure(task, 'Invalid output structure')
      return
    }
    
    await writeOutput(task, parsed)
    
  } catch (error) {
    await logFailure(task, String(error))
    // Don't throw — let the batch continue to the next task
  }
}
```

Every failed task goes into a failures log. Review failures manually and re-run or fix by hand.

## Concurrency

Local models process one request at a time (serial). Do not attempt parallel requests to the same Ollama instance — it serializes them anyway and queuing overhead slows everything down.

For parallel processing: run multiple Ollama instances on different ports, or use the Claude API (which handles concurrency natively).

## Overnight Batch Monitoring

Set up a simple progress file:

```typescript
// Before starting:
fs.writeFileSync('/tmp/batch-progress.json', JSON.stringify({
  total: tasks.length,
  completed: 0,
  failed: 0,
  startedAt: new Date().toISOString()
}))

// After each task:
const progress = JSON.parse(fs.readFileSync('/tmp/batch-progress.json'))
progress.completed++
fs.writeFileSync('/tmp/batch-progress.json', JSON.stringify(progress))
```

Check progress with: `cat /tmp/batch-progress.json`
