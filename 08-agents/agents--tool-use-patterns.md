# Agents: Tool Use Patterns

## Overview

Tools are how agents interact with the world — they call APIs, read files, run code, and query databases. Good tool design: one tool per concern, return structured data (not prose), make tools stateless, and validate inputs at the tool boundary. Poorly designed tools produce hallucinations, failed calls, and debugging nightmares.

## Tool Definition (Anthropic SDK)

```ts
import Anthropic from '@anthropic-ai/sdk'

const tools: Anthropic.Tool[] = [
  {
    name: 'search_products',
    description: 'Search for products by keyword, category, or price range. Returns matching products with ID, name, price, and stock status.',
    input_schema: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Search keyword or phrase',
        },
        category: {
          type: 'string',
          enum: ['electronics', 'clothing', 'books', 'home'],
          description: 'Filter by category (optional)',
        },
        max_price_cents: {
          type: 'integer',
          description: 'Maximum price in cents (optional)',
        },
        limit: {
          type: 'integer',
          description: 'Number of results to return (1-20, default 5)',
          default: 5,
        },
      },
      required: ['query'],
    },
  },
  {
    name: 'get_order',
    description: 'Retrieve a specific order by ID. Returns order details including status, items, and shipping info.',
    input_schema: {
      type: 'object',
      properties: {
        order_id: {
          type: 'string',
          description: 'The order UUID',
        },
      },
      required: ['order_id'],
    },
  },
]
```

## Tool Execution Loop

```ts
async function runAgent(userMessage: string): Promise<string> {
  const client = new Anthropic()
  const messages: Anthropic.MessageParam[] = [
    { role: 'user', content: userMessage },
  ]

  while (true) {
    const response = await client.messages.create({
      model: 'claude-opus-4-7',
      max_tokens: 4096,
      tools,
      messages,
    })

    // Add assistant response to conversation
    messages.push({ role: 'assistant', content: response.content })

    // Check stop reason
    if (response.stop_reason === 'end_turn') {
      // Extract final text response
      const textBlock = response.content.find(b => b.type === 'text')
      return textBlock?.text ?? 'No response'
    }

    if (response.stop_reason !== 'tool_use') {
      throw new Error(`Unexpected stop reason: ${response.stop_reason}`)
    }

    // Execute all tool calls and collect results
    const toolResults: Anthropic.ToolResultBlockParam[] = []

    for (const block of response.content) {
      if (block.type !== 'tool_use') continue

      const result = await executeTool(block.name, block.input)
      toolResults.push({
        type: 'tool_result',
        tool_use_id: block.id,
        content: JSON.stringify(result),
      })
    }

    // Feed tool results back to the model
    messages.push({ role: 'user', content: toolResults })
  }
}
```

## Tool Execution (Dispatch)

```ts
async function executeTool(name: string, input: Record<string, unknown>): Promise<unknown> {
  switch (name) {
    case 'search_products':
      return searchProducts(input as SearchProductsInput)
    case 'get_order':
      return getOrder(input.order_id as string)
    default:
      throw new Error(`Unknown tool: ${name}`)
  }
}

async function searchProducts(input: SearchProductsInput) {
  const products = await db.query.products.findMany({
    where: and(
      ilike(products.name, `%${input.query}%`),
      input.category ? eq(products.category, input.category) : undefined,
      input.max_price_cents ? lte(products.priceCents, input.max_price_cents) : undefined,
    ),
    limit: input.limit ?? 5,
    columns: { id: true, name: true, priceCents: true, inStock: true, category: true },
  })

  return {
    results: products.map(p => ({
      id: p.id,
      name: p.name,
      price: `$${(p.priceCents / 100).toFixed(2)}`,
      in_stock: p.inStock,
      category: p.category,
    })),
    total: products.length,
  }
}
```

## Error Handling in Tools

Return errors as structured data — don't throw in tool execution:

```ts
async function executeTool(name: string, input: Record<string, unknown>): Promise<unknown> {
  try {
    switch (name) {
      case 'get_order':
        const order = await getOrder(input.order_id as string)
        if (!order) return { error: 'Order not found', order_id: input.order_id }
        return order

      case 'search_products':
        return searchProducts(input as SearchProductsInput)

      default:
        return { error: `Tool "${name}" is not available` }
    }
  } catch (err) {
    logger.error({ tool: name, input, err }, 'Tool execution failed')
    return { error: 'Tool execution failed', message: (err as Error).message }
  }
}
```

## Tool Design Principles

```ts
// BAD: Tool that mixes concerns
{
  name: 'manage_product',
  description: 'Get, create, update, or delete a product',
  // Model has to figure out which operation — leads to errors
}

// GOOD: One tool per operation
{ name: 'get_product', description: 'Retrieve product by ID' }
{ name: 'create_product', description: 'Create a new product' }
{ name: 'update_product', description: 'Update product fields' }
{ name: 'delete_product', description: 'Delete a product' }

// BAD: Returns prose
return `Found 3 products matching "${query}": Widget A ($9.99), Widget B ($14.99), Widget C ($24.99)`

// GOOD: Returns structured data the model can reason about
return { results: [{ id: '...', name: 'Widget A', price_cents: 999 }, ...], total: 3 }
```

## Key Rules

- Tool names must be unique and unambiguous — the model selects tools by name.
- `description` is read by the model to decide when to call the tool — write it for the model, not humans.
- Mark required parameters in `required[]` — optional params should have sensible defaults.
- Return errors as `{ error: "..." }` objects, not thrown exceptions — the model can recover from returned errors.
- Parallelize independent tool calls by processing all `tool_use` blocks in one response concurrently.
