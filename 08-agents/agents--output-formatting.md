# Agent Pattern: Output Formatting

## Overview

Agents that return unstructured text are hard to consume downstream. Structured output — JSON, typed objects, or schema-validated responses — allows the calling code to extract data, handle errors, and chain operations reliably.

## JSON Schema Enforcement

The most reliable way to get structured output is to specify the exact schema in the prompt and validate the response:

```ts
import Ajv from 'ajv'

const ajv = new Ajv()

const invoiceSchema = {
  type: 'object',
  required: ['number', 'date', 'total_cents', 'vendor'],
  properties: {
    number: { type: 'string' },
    date: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
    total_cents: { type: 'integer', minimum: 0 },
    vendor: { type: 'string' },
    line_items: {
      type: 'array',
      items: {
        type: 'object',
        required: ['description', 'amount_cents'],
        properties: {
          description: { type: 'string' },
          amount_cents: { type: 'integer', minimum: 0 },
        },
      },
    },
  },
  additionalProperties: false,
}

const validate = ajv.compile(invoiceSchema)

function parseStructuredResponse(responseText: string): unknown {
  // Strip markdown code fences if present
  const cleaned = responseText
    .replace(/^```(?:json)?\s*/m, '')
    .replace(/\s*```\s*$/m, '')
    .trim()

  const parsed = JSON.parse(cleaned)

  if (!validate(parsed)) {
    const errors = validate.errors?.map(e => `${e.instancePath}: ${e.message}`).join(', ')
    throw new Error(`Response failed schema validation: ${errors}`)
  }

  return parsed
}
```

## Prompt Engineering for JSON Output

```
Extract invoice data from the text below.

Return ONLY valid JSON matching this schema:
{
  "number": "invoice number as string",
  "date": "YYYY-MM-DD format",
  "total_cents": integer (dollars × 100, no decimals),
  "vendor": "vendor company name",
  "line_items": [
    { "description": "string", "amount_cents": integer }
  ]
}

Rules:
- Return ONLY the JSON object, no explanation text
- If a field cannot be determined, omit it (don't use null)
- Dates must be YYYY-MM-DD format exactly
- All monetary amounts must be integers (cents)
- Do not include trailing commas

Invoice text:
---
{invoice_text}
---
```

The "Return ONLY the JSON" instruction is critical. Without it, models often wrap the JSON in explanatory text that breaks JSON.parse().

## Handling Markdown Code Fences

Models often wrap JSON in markdown code fences even when instructed not to:

```ts
function extractJson(text: string): string {
  // Try code fence first
  const fenceMatch = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/)
  if (fenceMatch) return fenceMatch[1]

  // Try finding JSON object/array directly
  const jsonMatch = text.match(/(\{[\s\S]*\}|\[[\s\S]*\])/)
  if (jsonMatch) return jsonMatch[0]

  // Assume the whole text is JSON
  return text.trim()
}
```

## Typed Output with Zod

```ts
import { z } from 'zod'

const InvoiceOutput = z.object({
  number: z.string(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  total_cents: z.number().int().nonnegative(),
  vendor: z.string(),
  line_items: z.array(z.object({
    description: z.string(),
    amount_cents: z.number().int().nonnegative(),
  })).optional(),
})

type Invoice = z.infer<typeof InvoiceOutput>

async function extractInvoice(text: string): Promise<Invoice> {
  const response = await llm.complete(buildPrompt(text))
  const json = extractJson(response)
  const parsed = JSON.parse(json)
  return InvoiceOutput.parse(parsed)  // Throws with clear errors if invalid
}
```

## Retry on Validation Failure

When the model returns invalid output, provide the error in a correction prompt:

```ts
async function extractWithRetry<T>(
  prompt: string,
  schema: z.ZodType<T>,
  maxAttempts = 3,
): Promise<T> {
  let lastResponse = ''
  let lastError = ''

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const correctionContext = attempt > 1
      ? `Previous attempt failed validation: ${lastError}\nPrevious output: ${lastResponse}\n\nPlease fix the output to match the required schema exactly.`
      : ''

    const response = await llm.complete(correctionContext + prompt)
    lastResponse = response

    try {
      const json = extractJson(response)
      const parsed = JSON.parse(json)
      return schema.parse(parsed)
    } catch (err) {
      lastError = err instanceof Error ? err.message : String(err)
      if (attempt === maxAttempts) throw err
    }
  }

  throw new Error('Max attempts exceeded')
}
```

## Partial Success Handling

When processing multiple items in one response, handle partial failures:

```ts
const MultiItemOutput = z.object({
  items: z.array(z.union([
    z.object({ success: z.literal(true), data: ItemSchema }),
    z.object({ success: z.literal(false), error: z.string(), raw: z.string() }),
  ])),
})

// In prompt: "For each item, return either { success: true, data: ... } or { success: false, error: '...reason...', raw: '...original...' }"
```

This lets one malformed item fail without losing all other successful items.
