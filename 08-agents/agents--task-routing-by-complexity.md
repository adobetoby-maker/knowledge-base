# Agent Pattern: Task Routing by Complexity

## Overview
Using an expensive capable model for every task — including trivial ones — wastes money and adds latency. Using a cheap fast model for complex reasoning tasks produces wrong results. Routing tasks to the appropriate model tier based on their complexity is a key cost-optimization and quality-optimization discipline. The router itself should use the cheapest model possible.

## Implementation

### Complexity Tiers

**Tier 1 — Mechanical/Fast model (Haiku, GPT-4o-mini, or equivalent):**
- Format conversion: JSON → CSV, camelCase → snake_case
- Simple text transformation: pluralization, capitalization, truncation
- Exact lookup: "what's the HTTP status code for rate limiting?"
- Boilerplate generation from a template
- Classification with clear categories and few edge cases
- Cost: 5-20x cheaper than Tier 3

**Tier 2 — Balanced model (Sonnet or equivalent):**
- CRUD endpoint generation
- Bug fixes with a clear error message and small codebase context
- Writing tests for existing code
- Summarizing a document or conversation
- Standard code reviews

**Tier 3 — Capable model (Opus, o3, or equivalent):**
- Architecture decisions with tradeoffs
- Debugging complex multi-service issues without a clear error
- Security analysis
- Novel algorithm design
- Long-horizon planning and task decomposition
- Tasks where wrong answers cause data loss or security issues

### Router Implementation
The router itself uses Tier 1 (cheap):
```typescript
async function routeTask(task: string): Promise<"tier1" | "tier2" | "tier3"> {
  const classification = await tier1Model.complete(`
    Classify this task by complexity:
    - "tier1": mechanical, formatting, simple lookup, boilerplate
    - "tier2": standard coding, summarization, testing
    - "tier3": architecture, security, debugging without clear cause, financial logic
    
    Task: "${task}"
    
    Respond with only: tier1, tier2, or tier3
  `);
  return classification.trim() as "tier1" | "tier2" | "tier3";
}
```

### Routing Table Example
```typescript
const ROUTING_RULES = [
  { pattern: /rename|format|convert/i, tier: "tier1" },
  { pattern: /scaffold|boilerplate|generate crud/i, tier: "tier1" },
  { pattern: /fix bug.*error:.*line \d+/i, tier: "tier2" },     // clear error
  { pattern: /fix bug.*intermittent|fix bug.*sometimes/i, tier: "tier3" },  // unclear
  { pattern: /architect|design system|security audit/i, tier: "tier3" },
  { pattern: /payment|billing|invoice amount/i, tier: "tier3" }, // financial = tier3
];
```

### Escalation Pattern
Start cheap, escalate if result is insufficient:
```typescript
async function executeWithEscalation(task: string, context: string) {
  const tier1Result = await tier1Model.complete(task, context);
  
  // Evaluate if tier1 result is sufficient
  const isInsufficient = await tier1Model.complete(`
    Is this result complete and correct?
    Task: ${task}
    Result: ${tier1Result}
    Answer: yes or no
  `);
  
  if (isInsufficient === "no") {
    console.log("Tier 1 insufficient — escalating to Tier 2");
    return await tier2Model.complete(task, context);
  }
  
  return tier1Result;
}
```

### Cost Reality Check
```
Example task breakdown for a typical sprint:
- 60 tasks: format, rename, boilerplate → Tier 1 → $0.12
- 30 tasks: CRUD, tests, summaries → Tier 2 → $1.80
- 10 tasks: architecture, debugging → Tier 3 → $4.00
Total: $5.92

Without routing (all Tier 3): $24.00
Savings: 75%
```

## Key Rules
- The router uses the cheapest model — the routing decision itself is a Tier 1 task
- When in doubt about tier, use the question: "Is a wrong answer here recoverable cheaply?" No → Tier 3
- All tasks involving money, auth, security, or data modification default to Tier 3 — the cost of a wrong answer exceeds model savings
- Escalation (start Tier 1, escalate if needed) is better than over-routing to Tier 3 by default
- Misrouting cheap tasks to Tier 3 is wasteful but safe; misrouting complex tasks to Tier 1 produces subtle wrong outputs that are hard to detect
- Track tier usage per task type over time — data reveals which task types are systematically mis-routed
