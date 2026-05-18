# Local Model: Data Validation

## Overview

Local models can validate free-text inputs against business rules that are hard to express as regex or schema constraints: "is this address real?", "does this description match the category?", "is this phone number formatted correctly for the stated country?". Use local models for validation that requires language understanding, not for simple format checks (use Zod for those).

## When to Use a Local Model for Validation

| Validation Type | Use Zod/Regex | Use Local Model |
|---|---|---|
| Email format | Yes | No |
| Required fields | Yes | No |
| "Is this a real business name?" | No | Yes |
| "Does this address sound US-formatted?" | No | Yes |
| "Is this description relevant to the category?" | No | Yes |
| Phone number format | Regex | No |
| "Is this a valid US phone number?" | libphonenumber | No |
| "Does this description contain prohibited content?" | No | Yes |

## Address Validation

```ts
interface AddressValidationResult {
  valid: boolean
  issues: string[]
  normalized?: string
}

async function validateAddress(address: string, countryCode: string): Promise<AddressValidationResult> {
  const prompt = `Validate this ${countryCode} address. Reply with JSON only.

Address: "${address}"

Rules:
- Must have a street number
- Must have a street name
- Must have a city
- For US: must have state (2-letter) and ZIP code
- For UK: must have postcode

Reply format: {"valid": true/false, "issues": ["list of problems"], "normalized": "cleaned version or null"}`

  const response = await ollama.chat({
    model: 'llama3.2:3b',
    messages: [{ role: 'user', content: prompt }],
    options: { temperature: 0 },
  })

  try {
    const text = response.message.content
    const jsonMatch = text.match(/\{[\s\S]*\}/)
    return jsonMatch ? JSON.parse(jsonMatch[0]) : { valid: false, issues: ['Validation failed'] }
  } catch {
    return { valid: false, issues: ['Could not parse validation result'] }
  }
}
```

## Content Category Matching

```ts
async function validateCategoryMatch(
  description: string,
  category: string,
  allowedCategories: string[]
): Promise<{ matches: boolean; suggestedCategory: string | null }> {
  const prompt = `Does this product description match the category "${category}"?

Description: "${description}"
Available categories: ${allowedCategories.join(', ')}

Reply with JSON: {"matches": true/false, "suggestedCategory": "best_match or null"}`

  const response = await ollama.chat({
    model: 'llama3.2:3b',
    messages: [{ role: 'user', content: prompt }],
    options: { temperature: 0 },
  })

  const text = response.message.content
  const jsonMatch = text.match(/\{[\s\S]*\}/)
  return jsonMatch
    ? JSON.parse(jsonMatch[0])
    : { matches: false, suggestedCategory: null }
}
```

## Batch Validation with Parallel Processing

```ts
async function validateBatch<T>(
  items: T[],
  validator: (item: T) => Promise<boolean>,
  concurrency = 3
): Promise<{ item: T; valid: boolean }[]> {
  const results: { item: T; valid: boolean }[] = []

  // Process in chunks to limit concurrent model calls
  for (let i = 0; i < items.length; i += concurrency) {
    const chunk = items.slice(i, i + concurrency)
    const chunkResults = await Promise.all(
      chunk.map(async item => ({
        item,
        valid: await validator(item),
      }))
    )
    results.push(...chunkResults)
  }

  return results
}

// Usage
const results = await validateBatch(
  products,
  p => validateCategoryMatch(p.description, p.category, CATEGORIES).then(r => r.matches),
  3  // 3 concurrent Ollama calls
)
```

## Validation with Structured Output

```ts
import { z } from 'zod'

const ValidationResultSchema = z.object({
  valid: z.boolean(),
  confidence: z.number().min(0).max(1),
  issues: z.array(z.string()),
})

async function validateWithStructuredOutput(text: string, rules: string): Promise<z.infer<typeof ValidationResultSchema>> {
  const response = await ollama.chat({
    model: 'llama3.2:3b',
    messages: [{
      role: 'user',
      content: `Validate this text against these rules. Return JSON only.
      
Rules: ${rules}
Text: "${text}"

JSON format: {"valid": bool, "confidence": 0.0-1.0, "issues": []}`,
    }],
    format: 'json',  // Ollama JSON mode
    options: { temperature: 0 },
  })

  try {
    return ValidationResultSchema.parse(JSON.parse(response.message.content))
  } catch {
    return { valid: false, confidence: 0, issues: ['Validation response parsing failed'] }
  }
}
```

## Key Rules

- Use local model validation as a supplementary check, not the sole gate — models can be wrong; combine with rule-based checks.
- Temperature 0 for validation — consistency matters more than creativity.
- Ollama's `format: 'json'` mode constrains output to valid JSON but doesn't guarantee your specific schema — validate the parsed output with Zod.
- Small models (3B) are sufficient for simple validation tasks; 7B for nuanced content checks.
- Cache validation results for identical inputs — validation calls the model every time, adding latency; a 1-hour cache prevents re-validating unchanged data.
