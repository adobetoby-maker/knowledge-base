# Tool Design for Agents

## The Core Problem
An agent's intelligence is only as good as the tools it has. Poorly designed tools produce agents that hallucinate parameters, retry unnecessarily, or get stuck choosing between tools that do overlapping things. Tool design is the highest-leverage part of agent architecture.

## Narrow and Focused

Each tool should do exactly one thing. `get_customer` is better than `get_entity`. `send_email` is better than `communicate`.

Why: agents use tool names and descriptions to decide which tool to call. Ambiguous scope forces the agent to reason about overlap. It will occasionally guess wrong. Narrow tools make selection unambiguous.

Bad: `manage_file(action: "read"|"write"|"delete", path, content?)` — one tool, three distinct operations, unclear which params apply when.

Good: `read_file(path)`, `write_file(path, content)`, `delete_file(path)` — three tools, zero ambiguity.

## Rich Return Values

A tool's return value is the agent's next input. If it's thin, the agent has to make another tool call to get context. Design returns to include everything needed to decide the next step.

```typescript
// Thin — agent must call get_order_status next
{ success: true, order_id: "ord_123" }

// Rich — agent has everything to decide what to do
{
  order_id: "ord_123",
  status: "awaiting_payment",
  amount_due: 149.00,
  due_date: "2026-05-25",
  payment_link: "https://...",
  next_action: "send_payment_reminder"  // hint, not a command
}
```

Include computed fields when they save the agent a reasoning step. Don't make the agent compute whether a deadline has passed — include `is_overdue: true`.

## Error Messages That Guide

When a tool fails, the agent reads the error message and decides what to do. An unhelpful error causes a retry loop or wrong recovery path.

```typescript
// Useless error
{ error: "invalid input" }

// Guiding error
{
  error: "customer_not_found",
  message: "No customer with id='cust_999'. Did you mean to search by email? Use search_customers(email: string) to find by email address.",
  suggestions: ["search_customers"]
}
```

Error messages should: name what went wrong, explain why, suggest the correct path forward. They're documentation that runs at runtime.

## Tool Documentation Format

The description string is what the agent reads. Treat it as the most important documentation in your codebase.

Structure:
1. One sentence: what the tool does
2. When to use it (vs similar tools)
3. Important constraints or side effects
4. Example parameter values

```
"Retrieves a customer record by their unique ID. Use this when you already have the customer ID from a previous lookup or order record. For finding customers by name or email, use search_customers instead. Returns full profile including contact info, preferences, and account status. IDs are format 'cust_XXXX'."
```

Keep descriptions under 200 words. Agents ignore long descriptions after the first paragraph.

## Expose vs Keep Internal

Not every function should be a tool. Tools visible to the agent expand its decision space and increase the chance of misuse.

**Expose as tools:**
- Actions the agent needs to decide to take (retrieving data, sending messages, creating records)
- Operations with meaningful outputs that affect next steps

**Keep internal (call from other tools):**
- Formatting and transformation (format_address — call it inside tools that return addresses)
- Auth and session management (inject headers internally, never expose as a tool)
- Logging and instrumentation
- Sub-steps of a larger operation that should always happen together

If two tools are always called in sequence, merge them into one. If a tool is only ever called from one other tool, make it a private function.

## Key Rules

- One action per tool; eliminate overlap between tools
- Return value should contain everything the agent needs for its next decision
- Error messages must name the problem and suggest the fix
- Tool descriptions are runtime documentation — write them like the agent's job depends on it (it does)
- Don't expose tools the agent should never choose independently — keep them internal
- If two tools are always called together, they're one tool
