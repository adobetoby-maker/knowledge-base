# Agent Pattern: Self-Correction

## Overview

Self-correction is the pattern of having an agent check its own output against explicit criteria and re-attempt if the output fails. It reduces supervisor burden for predictable failure modes.

## When to Use Self-Correction

Apply it when:
- Output has verifiable structure (JSON schema, valid code, specific fields present)
- Failure modes are predictable and recoverable (malformed JSON, missing required field)
- The correction prompt is simple and the error is clear

Don't apply it when:
- Failure is ambiguous (subjective quality, correctness requires domain knowledge)
- You're using it to paper over unclear instructions — fix the prompt instead
- The agent needs a human decision to proceed

## Basic Pattern

```ts
async function generateWithRetry<T>(
  prompt: string,
  validate: (output: string) => { valid: true; data: T } | { valid: false; error: string },
  maxAttempts = 3,
): Promise<T> {
  let lastError = ''
  
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const correctionContext = lastError
      ? `\n\nPrevious attempt failed validation: ${lastError}\nFix this issue and try again.`
      : ''

    const response = await callModel(prompt + correctionContext)
    const result = validate(response)
    
    if (result.valid) return result.data
    
    lastError = result.error
    console.log(`Attempt ${attempt} failed: ${result.error}`)
  }
  
  throw new Error(`Failed after ${maxAttempts} attempts. Last error: ${lastError}`)
}
```

The correction context carries forward the specific error. Vague re-prompts ("try again") don't help — include the exact failure reason.

## JSON Schema Validation

```ts
import Ajv from 'ajv'

const ajv = new Ajv()

function validateJSON<T>(schema: object) {
  const validate = ajv.compile(schema)
  
  return (output: string): { valid: true; data: T } | { valid: false; error: string } => {
    // Extract JSON from markdown code block if present
    const jsonMatch = output.match(/```(?:json)?\s*([\s\S]*?)```/) 
      ?? output.match(/(\{[\s\S]*\}|\[[\s\S]*\])/)
    
    const jsonStr = jsonMatch?.[1] ?? output.trim()
    
    try {
      const parsed = JSON.parse(jsonStr)
      if (validate(parsed)) {
        return { valid: true, data: parsed as T }
      }
      return { valid: false, error: ajv.errorsText(validate.errors) }
    } catch (e) {
      return { valid: false, error: `Invalid JSON: ${(e as Error).message}` }
    }
  }
}

// Usage
const result = await generateWithRetry(
  'Extract the order details as JSON: { orderId, items: [{ name, qty, price }], total }',
  validateJSON<OrderData>({
    type: 'object',
    required: ['orderId', 'items', 'total'],
    properties: {
      orderId: { type: 'string' },
      items: {
        type: 'array',
        items: {
          type: 'object',
          required: ['name', 'qty', 'price'],
        },
      },
      total: { type: 'number' },
    },
  }),
)
```

## Code Compilation Check

```ts
import { transpileModule } from 'typescript'

function validateTypeScript(output: string): { valid: true; data: string } | { valid: false; error: string } {
  const code = output.match(/```(?:typescript|tsx?)\s*([\s\S]*?)```/)?.[1] ?? output

  try {
    transpileModule(code, {
      compilerOptions: { strict: true, noEmit: true },
      reportDiagnostics: true,
    })
    return { valid: true, data: code }
  } catch (e) {
    return { valid: false, error: (e as Error).message }
  }
}
```

## Self-Reflection Prompt

For output without a machine-verifiable schema, use a second LLM call as the validator:

```ts
async function selfReflect(output: string, criteria: string[]): Promise<string | null> {
  const reflection = await callModel(`
Review this output against these criteria:
${criteria.map((c, i) => `${i + 1}. ${c}`).join('\n')}

Output to review:
${output}

If ALL criteria are met, respond with: PASS
If any criterion fails, respond with: FAIL: [specific criterion that failed and why]
`)

  if (reflection.startsWith('PASS')) return null
  return reflection.replace('FAIL: ', '')
}

// In the retry loop
const failureReason = await selfReflect(response, [
  'The summary is under 100 words',
  'The summary mentions the key stakeholders',
  'No first-person pronouns are used',
])
if (!failureReason) return parseResponse(response)
lastError = failureReason
```

## Limits

Cap retries at 3. After 3 failures, log the full context and escalate to a human queue or use a fallback (return null, return partial data, use a simpler prompt). Infinite retry loops are a production hazard — they consume tokens silently and mask broken prompts.

Log each attempt's failure reason. A recurring failure pattern means the prompt needs to be fixed, not retried.
