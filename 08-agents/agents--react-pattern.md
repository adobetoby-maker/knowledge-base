# ReAct Agent Pattern (Reason + Act)

## What ReAct Is

ReAct (Reasoning + Acting) structures agent execution as an explicit loop:
**Thought → Action → Observation → Thought → Action → ...**

Each iteration, the agent writes out its reasoning before choosing a tool. That reasoning is visible in the trace, influences the next thought, and catches errors before they compound.

## Why Reasoning Before Acting Matters

Without explicit reasoning, the model jumps straight to tool calls based on shallow pattern matching. With reasoning, it:

- Identifies what it already knows vs what it still needs
- Catches contradictions before executing an irreversible action
- Breaks multi-step plans into sequenced decisions
- Self-corrects: "The last result shows X, which means my earlier assumption was wrong"

Accuracy improves significantly on tasks requiring 3+ sequential decisions. The reasoning step is cheap (a few hundred tokens) compared to the cost of a wrong tool call followed by recovery.

## The Loop Structure

```
Thought: I need to find the customer's recent orders to check for refund eligibility.
         I have their email but not their ID, so I'll search first.
Action: search_customers(email="alice@example.com")
Observation: { customer_id: "cust_441", name: "Alice", account_status: "active" }

Thought: Got the ID. Now I need orders from the last 30 days. The refund window is 14 days
         so I need to check order dates carefully.
Action: list_orders(customer_id="cust_441", days=30)
Observation: [{ order_id: "ord_88", date: "2026-05-10", status: "delivered", amount: 49.99 }]

Thought: The order is 8 days old, within the 14-day window. Amount is $49.99 which is under
         the $100 no-approval threshold. Safe to process automatically.
Action: issue_refund(order_id="ord_88", reason="customer_request")
```

The Observation is always the raw tool result — never the agent's interpretation of it. Interpretation goes in the next Thought.

## Implementing with Tool Calling APIs

Modern tool calling APIs don't require a text scratchpad. The Thought becomes a `thinking` step or is embedded in the assistant turn before the tool call block:

```typescript
messages: [
  { role: "user", content: "Refund order ord_88 if eligible" },
  {
    role: "assistant",
    content: [
      { type: "text", text: "Let me check if this order is within the refund window..." },
      { type: "tool_use", name: "get_order", input: { order_id: "ord_88" } }
    ]
  },
  {
    role: "user",
    content: [{ type: "tool_result", tool_use_id: "...", content: "..." }]
  }
]
```

The text block before the tool call IS the Thought. The tool result IS the Observation. The loop continues until the agent produces a final text response with no tool call.

## Scratchpad Truncation

Long-running ReAct loops accumulate thousands of tokens of reasoning. At some point you need to truncate the scratchpad to stay within context limits.

Strategies in order of preference:
1. **Summarize completed phases** — compress earlier thought-action-observation triples into a summary paragraph: "Phase 1 complete: found customer cust_441, confirmed active account with no flags."
2. **Keep last N steps verbatim** — retain the 3-5 most recent iterations in full; summarize the rest
3. **Drop observations, keep thoughts** — observations can often be reconstructed; the reasoning chain has more value

Never truncate mid-loop. Complete the current iteration, then truncate before starting the next Thought.

## When ReAct Is Overkill

ReAct adds latency and token cost per step. Skip it when:
- The task is a single tool call (no chain of decisions needed)
- All steps are determined in advance (pipeline, not agent)
- Speed matters more than accuracy (use direct tool calling)

Use ReAct when: the path to the answer depends on what earlier steps return, the task involves conditional logic, or errors need in-loop self-correction.

## Key Rules

- Always write a Thought before each Action — never tool-call without reasoning
- Observations are raw tool outputs; interpretations go in the next Thought
- Truncate scratchpad by summarizing completed phases, not by dropping recent steps
- Use text blocks before tool calls in modern APIs rather than a separate reasoning format
- Skip ReAct for single-step tasks; use it whenever intermediate results change what to do next
