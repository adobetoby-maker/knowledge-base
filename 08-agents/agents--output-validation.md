# Agent Output Validation

## Why Validate Agent Output

LLM output is probabilistic — even with a schema, models can:
- Return valid JSON but wrong field names
- Return numbers as strings
- Omit required fields
- Wrap the JSON in extra explanation text
- Return different structures for edge cases

Validation at the boundary prevents bad data from propagating through a pipeline.

## Zod Validation Pattern

Define the schema first, validate all output:

```typescript
import { z } from 'zod'

// Schema for expected article output:
const ArticleOutputSchema = z.object({
  title: z.string().min(10).max(100),
  slug: z.string().regex(/^[a-z0-9-]+$/),
  excerpt: z.string().min(50).max(200),
  body: z.string().min(500),
  category: z.enum(['maintenance', 'repair', 'tips', 'news']),
  keywords: z.array(z.string()).min(3).max(10),
  readTimeMinutes: z.number().int().min(1).max(30),
})

type ArticleOutput = z.infer<typeof ArticleOutputSchema>

async function generateArticle(topic: string): Promise<ArticleOutput> {
  const response = await callLLM(`Generate an article about: ${topic}`)
  
  // Extract JSON from response:
  const json = extractJson(response)
  
  // Parse and validate:
  const result = ArticleOutputSchema.safeParse(json)
  
  if (!result.success) {
    throw new Error(`Invalid article output: ${result.error.message}`)
  }
  
  return result.data
}
```

## Retry on Validation Failure

For batch jobs, retry with stricter prompt before giving up:

```typescript
async function generateWithRetry<T>(
  schema: z.ZodType<T>,
  promptFn: (attempt: number, lastError?: string) => string,
  maxAttempts = 3
): Promise<T> {
  let lastError = ''
  
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const response = await callLLM(promptFn(attempt, lastError))
    const json = extractJson(response)
    const result = schema.safeParse(json)
    
    if (result.success) return result.data
    
    lastError = result.error.message
    console.warn(`Attempt ${attempt} failed validation: ${lastError}`)
  }
  
  throw new Error(`Failed after ${maxAttempts} attempts. Last error: ${lastError}`)
}

// Prompt gets stricter on retry:
const prompt = (attempt: number, lastError?: string) => {
  let base = `Generate a blog article about auto repair in Twin Falls, ID.
Return ONLY valid JSON matching this schema:
{ title, slug, excerpt, body, category, keywords[], readTimeMinutes }`
  
  if (attempt > 1) {
    base += `\n\nPrevious attempt failed: ${lastError}
IMPORTANT: Return ONLY the JSON object. No markdown. No explanation.`
  }
  
  return base
}
```

## Partial Output Handling

For structured documents (blog posts, reports), validate sections independently so partial output can be saved:

```typescript
const SectionSchema = z.object({
  heading: z.string(),
  content: z.string().min(100),
  order: z.number().int(),
})

interface ArticleWithSections {
  title: string
  sections: z.infer<typeof SectionSchema>[]
  invalidSections: unknown[]  // sections that failed validation
}

function parseArticleSections(raw: unknown[]): ArticleWithSections {
  const validSections: z.infer<typeof SectionSchema>[] = []
  const invalidSections: unknown[] = []
  
  for (const section of raw) {
    const result = SectionSchema.safeParse(section)
    if (result.success) {
      validSections.push(result.data)
    } else {
      invalidSections.push(section)
    }
  }
  
  return { title: '', sections: validSections, invalidSections }
}
```

## Coercion vs Rejection

Prefer coercion for minor issues, rejection for structural problems:

```typescript
const ArticleOutputSchema = z.object({
  title: z.string()
    .transform(s => s.trim()),  // coerce: trim whitespace
  
  readTimeMinutes: z.union([
    z.number(),
    z.string().transform(s => parseInt(s, 10))  // coerce: "5" → 5
  ]).pipe(z.number().int().min(1).max(60)),
  
  category: z.string()
    .transform(s => s.toLowerCase().replace(/\s+/g, '-'))
    .pipe(z.enum(['maintenance', 'repair', 'tips'])),  // normalize then validate
  
  // No coercion — structural problems should fail:
  sections: z.array(SectionSchema).min(3),
})
```

## Logging Failed Outputs

When validation fails in a batch job, save the raw output for debugging:

```typescript
if (!result.success) {
  // Save for human review:
  await fs.writeFile(
    `failed-outputs/${Date.now()}-${topicSlug}.json`,
    JSON.stringify({ topic, rawResponse: response, error: result.error.message }, null, 2)
  )
  // Continue to next item rather than aborting:
  errors.push({ topic, error: result.error.message })
  continue
}
```

This way you can review failures as a batch and refine prompts, rather than losing the pattern.
