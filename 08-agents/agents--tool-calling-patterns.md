# Agents: Tool Calling Patterns

## What This Solves

Tool calling (function calling) is how agents interact with external systems — reading files, querying databases, calling APIs. The patterns below cover: defining tools the model can call, validating inputs before execution, handling tool errors, and preventing runaway tool chains.

## Defining Tools

```ts
import Anthropic from '@anthropic-ai/sdk'

const client = new Anthropic()

const tools: Anthropic.Tool[] = [
  {
    name: 'get_invoice',
    description: 'Retrieve invoice details by ID. Returns invoice number, client name, status, and line items.',
    input_schema: {
      type: 'object' as const,
      properties: {
        invoice_id: {
          type: 'string',
          description: 'UUID of the invoice to retrieve',
          pattern: '^[0-9a-f-]{36}$',
        },
      },
      required: ['invoice_id'],
    },
  },
  {
    name: 'update_invoice_status',
    description: 'Update the status of an invoice. Valid statuses: draft, sent, paid, overdue, cancelled.',
    input_schema: {
      type: 'object' as const,
      properties: {
        invoice_id: { type: 'string' },
        status: { type: 'string', enum: ['draft', 'sent', 'paid', 'overdue', 'cancelled'] },
      },
      required: ['invoice_id', 'status'],
    },
  },
]
```

## Tool Execution Loop

```ts
async function runAgentWithTools(userMessage: string) {
  const messages: Anthropic.MessageParam[] = [
    { role: 'user', content: userMessage }
  ]

  let iterations = 0
  const MAX_ITERATIONS = 10  // Safety limit

  while (iterations < MAX_ITERATIONS) {
    iterations++

    const response = await client.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 4096,
      tools,
      messages,
    })

    // Add assistant response to conversation
    messages.push({ role: 'assistant', content: response.content })

    // If model is done, return the text
    if (response.stop_reason === 'end_turn') {
      return response.content.find(b => b.type === 'text')?.text ?? ''
    }

    // If model wants to use tools
    if (response.stop_reason === 'tool_use') {
      const toolResults: Anthropic.ToolResultBlockParam[] = []

      for (const block of response.content) {
        if (block.type !== 'tool_use') continue

        const result = await executeToolSafely(block.name, block.input as Record<string, unknown>)

        toolResults.push({
          type: 'tool_result',
          tool_use_id: block.id,
          content: result.success ? JSON.stringify(result.data) : result.error,
          is_error: !result.success,
        })
      }

      messages.push({ role: 'user', content: toolResults })
    }
  }

  throw new Error(`Agent exceeded ${MAX_ITERATIONS} iterations`)
}
```

## Safe Tool Execution

Validate inputs before executing, and never let tool errors crash the loop:

```ts
async function executeToolSafely(
  name: string,
  input: Record<string, unknown>
): Promise<{ success: true; data: unknown } | { success: false; error: string }> {
  try {
    switch (name) {
      case 'get_invoice': {
        const { invoice_id } = input as { invoice_id: string }
        // Validate UUID format before DB call
        if (!/^[0-9a-f-]{36}$/i.test(invoice_id)) {
          return { success: false, error: 'Invalid invoice_id format' }
        }
        const { data, error } = await supabaseAdmin
          .from('invoices')
          .select('*')
          .eq('id', invoice_id)
          .single()
        if (error) return { success: false, error: error.message }
        return { success: true, data }
      }

      case 'update_invoice_status': {
        const { invoice_id, status } = input as { invoice_id: string; status: string }
        const VALID_STATUSES = ['draft', 'sent', 'paid', 'overdue', 'cancelled']
        if (!VALID_STATUSES.includes(status)) {
          return { success: false, error: `Invalid status. Must be one of: ${VALID_STATUSES.join(', ')}` }
        }
        const { error } = await supabaseAdmin
          .from('invoices')
          .update({ status })
          .eq('id', invoice_id)
        if (error) return { success: false, error: error.message }
        return { success: true, data: { updated: true } }
      }

      default:
        return { success: false, error: `Unknown tool: ${name}` }
    }
  } catch (err) {
    return { success: false, error: err instanceof Error ? err.message : 'Unknown error' }
  }
}
```

## Tool Design Rules

**One tool, one concern**: `get_invoice` retrieves an invoice. `update_invoice_status` updates status. Don't create a single `manage_invoice` tool that does everything.

**Descriptions drive behavior**: Write tool descriptions as if explaining to a human what the function does and when to use it. The model reads these to decide which tool to call.

**Required vs optional parameters**: Only mark parameters as `required` if the tool truly can't run without them. Optional parameters should have defaults documented in the description.

**Return rich error messages**: If a tool fails, return a message that tells the model what to do differently. "Invoice not found with id=xyz" is more useful than "Error".

## Preventing Tool Abuse

Add guardrails for destructive operations:

```ts
// Require confirmation before destructive actions
case 'delete_invoice': {
  const { invoice_id, confirmed } = input
  if (!confirmed) {
    return {
      success: false,
      error: 'This operation requires confirmation. Call again with confirmed: true to proceed.',
    }
  }
  // ... proceed with deletion
}
```

Log every tool call for auditing:
```ts
await supabaseAdmin.from('agent_tool_calls').insert({
  session_id: sessionId,
  tool_name: name,
  input: JSON.stringify(input),
  success: result.success,
  created_at: new Date().toISOString(),
})
```
