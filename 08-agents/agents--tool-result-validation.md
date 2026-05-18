# Agent Pattern: Tool Result Validation

## Overview

Agents that call tools (APIs, databases, file operations) must validate the results before acting on them. An unvalidated tool result passed to the next step can cause cascading failures, incorrect outputs, or security issues.

## Why Tool Results Need Validation

Tool calls fail in non-obvious ways:
- API returns 200 with an error in the body
- Expected JSON field is null or missing
- Numeric value is a string `"1234"` not a number `1234`
- Array is empty when items were expected
- Timestamp is in an unexpected format
- Response is truncated or malformed

An agent treating these as successful results produces silently wrong output.

## Validation Schema per Tool

```ts
import { z } from 'zod'

// Define expected shape for each tool's output
const TOOL_SCHEMAS = {
  search_web: z.object({
    results: z.array(z.object({
      title: z.string(),
      url: z.string().url(),
      snippet: z.string(),
    })).min(1),
  }),

  get_weather: z.object({
    temperature: z.number(),
    unit: z.enum(['celsius', 'fahrenheit']),
    condition: z.string(),
    city: z.string(),
  }),

  create_invoice: z.object({
    id: z.string().uuid(),
    number: z.string(),
    status: z.enum(['draft', 'pending', 'paid']),
  }),

  list_files: z.array(z.string()),
}

type ToolName = keyof typeof TOOL_SCHEMAS

function validateToolResult<T extends ToolName>(
  toolName: T,
  result: unknown,
): z.infer<(typeof TOOL_SCHEMAS)[T]> {
  const schema = TOOL_SCHEMAS[toolName]
  const parsed = schema.safeParse(result)

  if (!parsed.success) {
    throw new Error(
      `Tool "${toolName}" returned unexpected format: ${parsed.error.issues.map(i => `${i.path.join('.')}: ${i.message}`).join(', ')}`
    )
  }

  return parsed.data
}
```

## Usage in Agent Loop

```ts
async function callTool(name: string, params: object): Promise<unknown> {
  const rawResult = await executeToolCall(name, params)

  // Validate if schema exists
  if (name in TOOL_SCHEMAS) {
    try {
      return validateToolResult(name as ToolName, rawResult)
    } catch (err) {
      console.error(`Tool validation failed for "${name}":`, err)
      // Return structured error for agent to handle
      return {
        _error: true,
        _tool: name,
        _message: (err as Error).message,
        _raw: rawResult,
      }
    }
  }

  return rawResult
}
```

## Handling Validation Errors in Agent Context

When a tool result fails validation, the agent needs to know. Include the error in the next turn's context:

```ts
interface ToolCallResult {
  toolName: string
  success: boolean
  data?: unknown
  error?: string
  rawResult?: unknown
}

function formatToolResultForContext(result: ToolCallResult): string {
  if (result.success) {
    return `Tool "${result.toolName}" succeeded:\n${JSON.stringify(result.data, null, 2)}`
  }

  return `Tool "${result.toolName}" FAILED validation:
Error: ${result.error}
Raw response: ${JSON.stringify(result.rawResult, null, 2).slice(0, 500)}

The tool call did not return the expected format. Either:
1. Try the tool again with different parameters
2. Use a different approach to get this information
3. Report that this information is unavailable`
}
```

## Null/Empty Result Handling

Many tool failures manifest as empty results rather than errors:

```ts
function assertNonEmpty<T>(result: T[], toolName: string, query: string): void {
  if (result.length === 0) {
    throw new EmptyResultError(
      `Tool "${toolName}" returned 0 results for query "${query}". ` +
      'Consider broadening the search or trying alternative terms.'
    )
  }
}

class EmptyResultError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'EmptyResultError'
  }
}
```

## Type Coercion

Some tools return numbers as strings or dates as Unix timestamps. Validate AND coerce:

```ts
const FlexibleInvoiceSchema = z.object({
  id: z.string(),
  amount: z.union([
    z.number(),
    z.string().transform(Number),  // Coerce "1234" → 1234
  ]),
  created_at: z.union([
    z.string().datetime(),
    z.number().transform((ts) => new Date(ts * 1000).toISOString()),  // Unix → ISO
  ]),
})
```

## Logging for Debugging

Log every tool call result before validation to help debug failures in production:

```ts
async function callToolWithLogging(name: string, params: object): Promise<unknown> {
  const start = Date.now()
  let rawResult: unknown
  let validationError: Error | null = null

  try {
    rawResult = await executeToolCall(name, params)
    const validated = validateToolResult(name as ToolName, rawResult)

    console.log('tool_call', {
      tool: name,
      params,
      duration: Date.now() - start,
      success: true,
    })

    return validated
  } catch (err) {
    validationError = err as Error
    console.error('tool_call_failed', {
      tool: name,
      params,
      duration: Date.now() - start,
      error: validationError.message,
      rawResult: JSON.stringify(rawResult).slice(0, 500),
    })
    throw validationError
  }
}
```
