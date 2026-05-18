# Local Model: Quality Control and Output Verification

## The Problem

Local models produce lower-quality output than frontier models for complex tasks. They also fail silently more often — returning plausible-looking but incorrect results, truncating without warning, or hallucinating structure. Automated QC pipelines catch these problems before outputs enter your codebase.

## Output Schema Validation

Always define what you expect and reject anything that doesn't match:

```ts
import { z } from 'zod'

const ArticleSchema = z.object({
  title: z.string().min(10).max(100),
  excerpt: z.string().min(50).max(200),
  body: z.string().min(300),
  keywords: z.array(z.string()).min(2).max(10),
})

async function generateAndValidate(prompt: string): Promise<z.infer<typeof ArticleSchema>> {
  const raw = await callOllama('llama3.2:8b', prompt)

  // Extract JSON from model output (models often add prose around JSON)
  const jsonMatch = raw.match(/\{[\s\S]*\}/)
  if (!jsonMatch) throw new Error('Model did not return JSON')

  const parsed = JSON.parse(jsonMatch[0])
  return ArticleSchema.parse(parsed)  // Throws with details if validation fails
}
```

## Retry with Stricter Prompt

When the first attempt fails validation:

```ts
async function generateWithRetry(
  prompt: string,
  schema: z.ZodType<unknown>,
  maxRetries = 3,
): Promise<unknown> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    const raw = await callOllama('llama3.2:8b', attempt === 0
      ? prompt
      : `${prompt}\n\nIMPORTANT: Return ONLY valid JSON. Previous attempt failed validation.`
    )

    try {
      const parsed = JSON.parse(extractJson(raw))
      return schema.parse(parsed)
    } catch (err) {
      if (attempt === maxRetries - 1) {
        console.error(`Failed after ${maxRetries} attempts:`, err)
        throw err
      }
      console.warn(`Attempt ${attempt + 1} failed: ${err instanceof Error ? err.message : err}`)
    }
  }
}
```

## Content Quality Scoring

Automated scoring before human review:

```ts
interface QualityScore {
  total: number           // 0-100
  wordCount: number
  hasKeyword: boolean
  hasHeadings: boolean
  readabilityOk: boolean
  noAiPhrases: boolean
  flags: string[]
}

const AI_PHRASES = [
  'in today\'s digital landscape',
  'it\'s worth noting that',
  'at the end of the day',
  'in conclusion',
  'moreover',
  'furthermore',
  'needless to say',
]

function scoreContent(content: string, primaryKeyword: string): QualityScore {
  const words = content.split(/\s+/).filter(Boolean)
  const flags: string[] = []

  const wordCount = words.length
  if (wordCount < 300) flags.push(`Too short: ${wordCount} words`)

  const hasKeyword = content.toLowerCase().includes(primaryKeyword.toLowerCase())
  if (!hasKeyword) flags.push(`Missing primary keyword: "${primaryKeyword}"`)

  const headingCount = (content.match(/^#{1,3} /gm) || []).length
  const hasHeadings = headingCount >= 2
  if (!hasHeadings) flags.push('Fewer than 2 headings')

  const aiPhrases = AI_PHRASES.filter(p => content.toLowerCase().includes(p))
  if (aiPhrases.length > 0) flags.push(`AI phrases detected: ${aiPhrases.join(', ')}`)

  const avgSentenceLength = wordCount / (content.split(/[.!?]/).length || 1)
  const readabilityOk = avgSentenceLength < 25

  let total = 100
  if (!hasKeyword) total -= 30
  if (!hasHeadings) total -= 20
  if (wordCount < 300) total -= 20
  if (aiPhrases.length > 0) total -= 10 * aiPhrases.length

  return {
    total: Math.max(0, total),
    wordCount,
    hasKeyword,
    hasHeadings,
    readabilityOk,
    noAiPhrases: aiPhrases.length === 0,
    flags,
  }
}
```

## Duplicate Detection

Local models sometimes produce near-identical outputs for different inputs:

```ts
function detectDuplicates(outputs: string[]): Set<number> {
  const duplicates = new Set<number>()
  const seen = new Map<string, number>()

  for (let i = 0; i < outputs.length; i++) {
    // Normalize: lowercase, collapse whitespace
    const normalized = outputs[i].toLowerCase().replace(/\s+/g, ' ').trim()
    // Use first 200 chars as fingerprint
    const fingerprint = normalized.slice(0, 200)

    if (seen.has(fingerprint)) {
      duplicates.add(i)
      duplicates.add(seen.get(fingerprint)!)
    } else {
      seen.set(fingerprint, i)
    }
  }

  return duplicates
}
```

## Spot Check Report

After a batch run, generate a human-readable report of items needing review:

```ts
async function generateQCReport(results: Array<{ input: string; output: string; score: QualityScore }>) {
  const failures = results.filter(r => r.score.total < 70)
  const warnings = results.filter(r => r.score.total >= 70 && r.score.total < 85)

  const report = `
# QC Report — ${new Date().toISOString()}

Total: ${results.length}
Passed (≥85): ${results.length - failures.length - warnings.length}
Warnings (70–84): ${warnings.length}
Failures (<70): ${failures.length}

## Items Requiring Review

${failures.map(f => `### FAIL (${f.score.total}/100)
Input: ${f.input.slice(0, 100)}
Issues: ${f.score.flags.join(', ')}
Output preview: ${f.output.slice(0, 200)}
`).join('\n')}
`

  fs.writeFileSync('/tmp/qc-report.md', report)
  console.log(report)
}
```

## Thresholds for Production

| Score | Action |
|-------|--------|
| 85–100 | Auto-approve, add to content pipeline |
| 70–84 | Flag for quick human review |
| < 70 | Reject, regenerate with improved prompt |

Never auto-publish anything that fails keyword or heading checks — these are the minimum viable signals that the model understood the task.
