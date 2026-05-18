# Local Model Output Parsing

## The Problem

Local models don't follow output format instructions reliably. A prompt that says "respond with JSON only" may produce:
- Valid JSON
- JSON wrapped in markdown code fences
- JSON with explanatory text before it
- Partial JSON
- Plain prose instead of JSON
- JSON with comments (invalid)

Always parse defensively.

## JSON Extraction Strategies

```typescript
function extractJSON(raw: string): unknown | null {
  // Strategy 1: Try direct parse (model followed instructions):
  try {
    return JSON.parse(raw.trim())
  } catch {
    // Not valid JSON — try other strategies
  }
  
  // Strategy 2: Extract from code fence:
  // ```json\n{...}\n```
  const fenceMatch = raw.match(/```(?:json)?\s*\n([\s\S]*?)\n```/)
  if (fenceMatch) {
    try {
      return JSON.parse(fenceMatch[1].trim())
    } catch {}
  }
  
  // Strategy 3: Find the outermost { } block:
  const objectMatch = raw.match(/\{[\s\S]*\}/)
  if (objectMatch) {
    try {
      return JSON.parse(objectMatch[0])
    } catch {}
  }
  
  // Strategy 4: Find the outermost [ ] block:
  const arrayMatch = raw.match(/\[[\s\S]*\]/)
  if (arrayMatch) {
    try {
      return JSON.parse(arrayMatch[0])
    } catch {}
  }
  
  return null  // couldn't extract JSON
}
```

## Typed JSON Extraction with Zod

After extracting JSON, validate it matches the expected shape:

```typescript
import { z } from 'zod'

const ArticleSchema = z.object({
  title: z.string().min(1),
  body: z.string().min(100),
  excerpt: z.string().optional(),
})

type Article = z.infer<typeof ArticleSchema>

function parseArticleOutput(raw: string): Article | null {
  const json = extractJSON(raw)
  if (!json) return null
  
  const result = ArticleSchema.safeParse(json)
  if (!result.success) {
    console.error('Invalid article structure:', result.error.flatten())
    return null
  }
  
  return result.data
}
```

## Text Extraction (Non-JSON)

When the output should be prose (an article body, description, code):

```typescript
function extractText(raw: string, options?: {
  stripCodeFence?: boolean
  minLength?: number
}): string | null {
  let text = raw.trim()
  
  // Remove markdown code fences if present:
  if (options?.stripCodeFence) {
    text = text.replace(/^```[\w]*\n/, '').replace(/\n```$/, '').trim()
  }
  
  // Remove common preambles local models add:
  const preambles = [
    /^Here(?:'s| is) (?:the |an? )?(?:article|blog post|content):\s*/i,
    /^(?:Sure|Certainly|Of course)[!,.]?\s*/i,
    /^As requested,?\s*/i,
  ]
  for (const preamble of preambles) {
    text = text.replace(preamble, '').trim()
  }
  
  if (options?.minLength && text.length < options.minLength) {
    return null  // too short — generation failed
  }
  
  return text
}
```

## Code Extraction

```typescript
function extractCode(raw: string, language?: string): string | null {
  // Try language-specific code fence:
  if (language) {
    const match = raw.match(new RegExp(`\`\`\`${language}\\s*\\n([\\s\\S]*?)\\n\`\`\``))
    if (match) return match[1].trim()
  }
  
  // Try any code fence:
  const fenceMatch = raw.match(/```[\w]*\s*\n([\s\S]*?)\n```/)
  if (fenceMatch) return fenceMatch[1].trim()
  
  // If no code fence, return raw (model may have skipped fencing):
  return raw.trim()
}
```

## Handling Truncated Output

Local models may stop mid-generation due to context limits:

```typescript
function isCompleteJSON(text: string): boolean {
  const trimmed = text.trim()
  
  // Count open vs closed braces/brackets:
  let depth = 0
  let inString = false
  let escaped = false
  
  for (const char of trimmed) {
    if (escaped) { escaped = false; continue }
    if (char === '\\') { escaped = true; continue }
    if (char === '"') { inString = !inString; continue }
    if (inString) continue
    
    if (char === '{' || char === '[') depth++
    if (char === '}' || char === ']') depth--
  }
  
  return depth === 0 && trimmed.length > 0
}
```

## Prompting for Reliable Output

Make local model output more parseable with precise prompts:

```typescript
// FRAGILE — local models often add preamble:
const prompt = 'Write a JSON object with title and body fields.'

// ROBUST — give an example and use XML-style delimiters:
const prompt = `Generate a blog post as JSON.

Output ONLY this JSON structure, nothing else:
{"title": "...", "body": "...", "excerpt": "..."}

Topic: ${topic}`

// Even more robust — use start tokens:
const prompt = `${topic}

JSON:
`
// Many models will continue the JSON from the "JSON:" prefix
```

## Retry Logic When Parsing Fails

```typescript
async function generateWithParsing<T>(
  generateFn: () => Promise<string>,
  parseFn: (raw: string) => T | null,
  maxAttempts = 3
): Promise<T | null> {
  for (let i = 0; i < maxAttempts; i++) {
    const raw = await generateFn()
    const parsed = parseFn(raw)
    
    if (parsed !== null) return parsed
    
    console.log(`Parse attempt ${i + 1} failed. Raw: ${raw.substring(0, 100)}...`)
  }
  
  return null
}
```
