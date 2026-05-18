# Skill: LLM Function/Tool Calling

## Overview
Tool calling lets an LLM decide when to call a function and with what arguments, then reason over the result. The failure modes that cause production incidents: passing unvalidated LLM-generated args to business logic, not handling the multi-turn loop correctly, and treating the LLM's tool decision as authoritative (it can hallucinate args). Always validate before executing.

## Implementation

### 1. Define tools with strict JSON schema
```ts
const tools = [
  {
    name: 'get_order',
    description: 'Retrieve an order by ID. Use when the user asks about a specific order status or details.',
    input_schema: {
      type: 'object',
      properties: {
        order_id: {
          type: 'string',
          description: 'The order ID (format: ORD-XXXXXXXX)',
          pattern: '^ORD-[A-Z0-9]{8}$',  // constrain format in schema
        },
      },
      required: ['order_id'],
      additionalProperties: false,  // reject extra fields
    },
  },
  {
    name: 'list_orders',
    description: 'List orders for the authenticated user. Use when user asks to see their orders.',
    input_schema: {
      type: 'object',
      properties: {
        status: {
          type: 'string',
          enum: ['pending', 'shipped', 'delivered', 'cancelled'],
        },
        limit: { type: 'integer', minimum: 1, maximum: 50, default: 10 },
      },
      additionalProperties: false,
    },
  },
];
```

### 2. Validate args with Zod before executing
```ts
import { z } from 'zod';

const GetOrderArgs = z.object({
  order_id: z.string().regex(/^ORD-[A-Z0-9]{8}$/),
});

const ListOrdersArgs = z.object({
  status: z.enum(['pending', 'shipped', 'delivered', 'cancelled']).optional(),
  limit: z.number().int().min(1).max(50).default(10),
});

// Map tool names to handlers
const toolHandlers: Record<string, (args: unknown) => Promise<unknown>> = {
  get_order: async (args) => {
    const { order_id } = GetOrderArgs.parse(args);  // throws ZodError if invalid
    const order = await db.orders.findUnique({ where: { id: order_id } });
    if (!order) return { error: 'Order not found' };
    return order;
  },
  list_orders: async (args) => {
    const { status, limit } = ListOrdersArgs.parse(args);
    return db.orders.findMany({ where: status ? { status } : {}, take: limit });
  },
};
```

### 3. Agentic loop (multi-turn tool execution)
```ts
import Anthropic from '@anthropic-ai/sdk';

const client = new Anthropic();

async function runWithTools(userMessage: string, userId: string): Promise<string> {
  const messages: Anthropic.MessageParam[] = [
    { role: 'user', content: userMessage },
  ];

  // Loop until model stops requesting tools
  while (true) {
    const response = await client.messages.create({
      model: 'claude-haiku-4-5',
      max_tokens: 1024,
      system: `You are a helpful order support agent for user ${userId}.`,
      tools,
      messages,
    });

    // Model finished — return text response
    if (response.stop_reason === 'end_turn') {
      const textBlock = response.content.find(b => b.type === 'text');
      return textBlock?.text ?? '';
    }

    // Model wants to use tools
    if (response.stop_reason === 'tool_use') {
      // Add assistant's response to conversation
      messages.push({ role: 'assistant', content: response.content });

      // Execute each requested tool
      const toolResults: Anthropic.ToolResultBlockParam[] = [];
      for (const block of response.content) {
        if (block.type !== 'tool_use') continue;

        let result: unknown;
        const handler = toolHandlers[block.name];
        
        if (!handler) {
          result = { error: `Unknown tool: ${block.name}` };
        } else {
          try {
            result = await handler(block.input);
          } catch (err) {
            // ZodError or business logic error — tell model, don't crash
            result = { error: err instanceof Error ? err.message : 'Tool execution failed' };
          }
        }

        toolResults.push({
          type: 'tool_result',
          tool_use_id: block.id,
          content: JSON.stringify(result),
        });
      }

      // Add tool results back into conversation
      messages.push({ role: 'user', content: toolResults });
    }
  }
}
```

## Key Rules
- **Validate LLM-generated args with Zod before executing** — the model can hallucinate field names, wrong types, or values outside allowed enums.
- **Never execute arbitrary code from LLM output** — tools must be a closed set of pre-defined functions you control.
- Return structured errors to the model (not throw) — the model can recover and try differently instead of crashing the loop.
- Keep tool descriptions precise and distinct — ambiguous descriptions cause the model to pick the wrong tool.
- Use `additionalProperties: false` in JSON schema — rejects hallucinated extra fields before they reach your handler.
- Cap max loop iterations (e.g., 10) to prevent infinite tool loops from runaway model behavior.
- Log every tool call and result for debugging — agentic loops are hard to trace without this.
- Enforce authorization in tool handlers, not schema — the model doesn't enforce user-level permissions.
