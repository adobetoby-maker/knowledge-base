# Agent Pattern: Tool Documentation for Agents

## Overview
An agent is only as capable as its tools, and tools are only usable if they're well-documented. Without clear parameter descriptions, return formats, and error cases, agents hallucinate parameter names, miss required fields, and misinterpret return values. A tool description is a contract: what goes in, what comes out, and what can go wrong.

## Implementation

### Tool Definition Structure
Every tool needs these five components:

```typescript
{
  name: "create_invoice",

  description: `
    Creates a new invoice for a customer. Returns the created invoice with its ID.
    Use this when you need to generate a new invoice from line items.
    Do NOT use this for updating existing invoices — use update_invoice instead.
  `,

  parameters: {
    type: "object",
    required: ["customer_id", "line_items"],
    properties: {
      customer_id: {
        type: "string",
        format: "uuid",
        description: "The UUID of the customer. Must exist in the customers table.",
      },
      line_items: {
        type: "array",
        minItems: 1,
        description: "At least one line item is required.",
        items: {
          type: "object",
          required: ["description", "amount_cents"],
          properties: {
            description: {
              type: "string",
              maxLength: 200,
              description: "Human-readable description shown on the invoice.",
            },
            amount_cents: {
              type: "integer",
              minimum: 0,
              description: "Amount in cents (e.g. 4999 = $49.99). Must be non-negative.",
            },
          },
        },
      },
      due_date: {
        type: "string",
        format: "date",
        description: "ISO 8601 date (YYYY-MM-DD). Defaults to 30 days from today if omitted.",
      },
    },
  },

  returns: {
    description: `
      On success: { id: string, status: "draft", total_cents: number, created_at: string }
      On error: { error: string, code: "CUSTOMER_NOT_FOUND" | "VALIDATION_ERROR" | "DB_ERROR" }
    `,
  },
}
```

### Usage Example in Description
The single most effective improvement to tool descriptions is adding a concrete example call:
```
Example usage:
{
  "customer_id": "a3f7e2d1-...",
  "line_items": [
    { "description": "Oil change", "amount_cents": 4999 },
    { "description": "Labor", "amount_cents": 8000 }
  ],
  "due_date": "2026-06-01"
}

Returns:
{
  "id": "inv_8x2k...",
  "status": "draft",
  "total_cents": 12999,
  "created_at": "2026-05-18T10:00:00Z"
}
```

### Error Cases Are Required
```
Error cases:
- CUSTOMER_NOT_FOUND: customer_id doesn't exist in the database
- VALIDATION_ERROR: a required field is missing or a value is out of range
- DUPLICATE_INVOICE: an identical invoice exists within the last 5 minutes (idempotency guard)
- DB_ERROR: unexpected database error — retry once before surfacing to user
```

Without error cases, the agent doesn't know whether to retry, surface the error, or try an alternative path.

### Disambiguation from Similar Tools
```
// In the description of update_invoice:
"Use create_invoice to create new invoices. Use this tool only to modify an existing invoice's
line items, due date, or metadata. Cannot change customer_id after creation."
```

## Key Rules
- The `description` field does more work than `parameters` — use it to explain WHEN to use the tool, not just what it does
- Required parameters must be marked `required: [...]` — agents skip required params if only the description says "required"
- Include at least one example call and example return value — examples are processed more reliably than prose descriptions
- Document every error code and what the agent should do when it occurs (retry, abort, try alternative)
- When two tools do similar things, each one must explicitly reference the other and clarify when NOT to use itself
- Parameter types should use `format` constraints where applicable (`uuid`, `date`, `email`) — agents honor these in validation
- Return type descriptions should show both success and error shapes — agents need to know what to parse
