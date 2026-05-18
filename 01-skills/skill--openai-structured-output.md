# Skill: LLM Structured Output

## Overview
LLMs produce unstructured text by default, which is brittle to parse. Structured output mode constrains the model to produce JSON that exactly matches a provided schema — guaranteed by the model runtime, not by prompt instructions. This replaces ad-hoc JSON parsing, regex extraction, and retry loops for extraction tasks. Use Zod to define schemas once and derive both the TypeScript type and the JSON Schema from it.

## OpenAI Structured Output (Strict Mode)

`response_format: { type: "json_schema" }` with `strict: true` forces the model to emit valid JSON matching the schema exactly. No extra fields, no missing required fields.

```ts
import OpenAI from 'openai'
import { zodResponseFormat } from 'openai/helpers/zod'
import { z } from 'zod'

const openai = new OpenAI()

// Define schema with Zod
const ExtractedInvoice = z.object({
  vendor: z.string(),
  invoice_number: z.string(),
  total_amount: z.number(),
  currency: z.enum(['USD', 'EUR', 'GBP']),
  line_items: z.array(z.object({
    description: z.string(),
    quantity: z.number(),
    unit_price: z.number(),
  })),
  due_date: z.string().nullable(),
})

type ExtractedInvoice = z.infer<typeof ExtractedInvoice>

async function extractInvoice(text: string): Promise<ExtractedInvoice> {
  const completion = await openai.beta.chat.completions.parse({
    model: 'gpt-4o-2024-08-06',  // structured output requires this model or newer
    messages: [
      { role: 'system', content: 'Extract invoice data from the provided text.' },
      { role: 'user', content: text },
    ],
    response_format: zodResponseFormat(ExtractedInvoice, 'invoice'),
  })

  const result = completion.choices[0].message.parsed
  if (!result) throw new Error('Model refused to parse')
  return result
}
```

## Manual JSON Schema (Without Zod Helper)

```ts
const response = await openai.chat.completions.create({
  model: 'gpt-4o-2024-08-06',
  messages: [{ role: 'user', content: '...' }],
  response_format: {
    type: 'json_schema',
    json_schema: {
      name: 'product_analysis',
      strict: true,
      schema: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          category: { type: 'string', enum: ['electronics', 'clothing', 'food'] },
          price_range: { type: 'string' },
          sentiment: { type: 'number', description: '-1 to 1' },
        },
        required: ['name', 'category', 'price_range', 'sentiment'],
        additionalProperties: false,  // required for strict mode
      },
    },
  },
})

const data = JSON.parse(response.choices[0].message.content!)
```

## Anthropic Structured Output

Anthropic uses tool calling for structured output:

```ts
import Anthropic from '@anthropic-ai/sdk'

const anthropic = new Anthropic()

const response = await anthropic.messages.create({
  model: 'claude-opus-4-5',
  max_tokens: 1024,
  tools: [{
    name: 'extract_data',
    description: 'Extract structured data from text',
    input_schema: {
      type: 'object',
      properties: {
        summary: { type: 'string' },
        topics: { type: 'array', items: { type: 'string' } },
        sentiment: { type: 'string', enum: ['positive', 'neutral', 'negative'] },
      },
      required: ['summary', 'topics', 'sentiment'],
    },
  }],
  tool_choice: { type: 'tool', name: 'extract_data' },  // force tool use
  messages: [{ role: 'user', content: text }],
})

const toolUse = response.content.find(b => b.type === 'tool_use')
const data = toolUse?.input  // already parsed, not a string
```

## Retry on Schema Violation

With strict mode, violations are rare. Without strict mode, add a validation layer:

```ts
async function extractWithRetry<T>(
  schema: z.ZodType<T>,
  messages: any[],
  attempts = 2
): Promise<T> {
  for (let i = 0; i < attempts; i++) {
    const response = await openai.chat.completions.create({ model: 'gpt-4o', messages })
    try {
      const json = JSON.parse(response.choices[0].message.content!)
      return schema.parse(json)
    } catch (err) {
      if (i === attempts - 1) throw err
      // Add error to messages to guide correction
      messages.push(
        { role: 'assistant', content: response.choices[0].message.content },
        { role: 'user', content: `Schema validation failed: ${err}. Please fix and return valid JSON.` }
      )
    }
  }
  throw new Error('unreachable')
}
```

## Structured Output Replaces Function Calling for Extraction

Old pattern (function calling): define a function, model "calls" it, you parse arguments.
New pattern (structured output): define a JSON schema, model emits matching JSON directly.

Structured output is simpler for pure extraction. Use function/tool calling when you actually need to execute code based on the model's decision.

## Key Rules
- `strict: true` + `additionalProperties: false` + all fields in `required` is the contract for guaranteed adherence
- Zod schema → JSON schema via `zodResponseFormat` avoids maintaining two schemas
- Check `message.refusal` — some prompts trigger a refusal instead of structured output
- Schema nesting is limited to 5 levels deep in strict mode
- Large schemas slow down responses — keep schemas focused on what you actually need
- `json_object` response format produces JSON but doesn't guarantee schema — use `json_schema` for guarantees
