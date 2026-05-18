# Agent Pattern: Cost-Bounded Execution

## Overview
Long-running autonomous agent tasks can consume unexpectedly large token budgets — especially if they encounter problems, retry loops, or unexpectedly large codebases. A cost-bounded agent sets a token budget upfront, tracks usage per step, checkpoints progress when approaching the limit, and delivers partial results rather than truncating mid-task.

## Implementation

### Budget Initialization
```typescript
interface AgentBudget {
  totalBudget: number;       // total tokens allocated for the task
  used: number;              // tokens consumed so far
  reserved: number;          // tokens to reserve for final output formatting
  checkpointAt: number;      // percentage at which to checkpoint and assess
}

const budget: AgentBudget = {
  totalBudget: 50_000,
  used: 0,
  reserved: 2_000,
  checkpointAt: 0.8,         // checkpoint at 80% usage
};
```

### Per-Step Tracking
After each step, log token consumption:
```
## Step 3/10: Analyze components

[... processing ...]

Step complete.
Budget: 12,400 / 50,000 tokens used (24.8%)
Breakdown:
  - Step 1 (audit): 2,100 tokens
  - Step 2 (plan): 1,800 tokens
  - Step 3 (analyze components): 8,500 tokens ← expensive step
  
At this rate, estimate remaining budget will support ~5 more steps at current complexity.
```

### Checkpoint at Budget Threshold
```
Budget checkpoint: 80% consumed (40,000 / 50,000 tokens)

Progress so far:
✓ Steps 1-7 complete (out of 10)
✗ Steps 8-10 remaining

At current usage rate, cannot complete all remaining steps within budget.

Options:
1. Deliver partial results for steps 1-7 now, continue in a new session
2. Compress steps 8-10 into a summary-level output (less detailed)
3. Skip step 9 (least critical) and complete 8 + 10

Recommending Option 1 — proceeding with partial delivery unless instructed otherwise.
```

### Partial Result Delivery
```
## Partial Results (Steps 1-7 of 10)

[Complete output for steps 1-7]

---
## Incomplete Steps

Step 8: Refactor authentication module
  Status: Not started
  Estimated effort: 3,000-4,000 tokens
  Dependencies: Requires step 7 output (complete) ✓

Step 9: Update test suite
  Status: Not started  
  Estimated effort: 5,000 tokens

Step 10: Update documentation
  Status: Not started
  Estimated effort: 1,500 tokens

## Resumption Instructions
To continue: "Continue from step 8. Context: [paste key outputs from steps 4-7]"
```

### Expensive Step Detection
```typescript
// Heuristics for identifying expensive steps:
const expensivePatterns = [
  "analyze entire codebase",
  "process all files",
  "generate documentation for every",
  "review all tests",
];
// Flag these before starting and estimate token cost
```

## Key Rules
- Set the token budget before starting, not after — post-hoc budgets don't constrain behavior
- Track cost per step, not just total — knowing which steps are expensive informs future task scoping
- Reserve tokens for output formatting — an agent that runs out of budget mid-sentence produces unusable output
- Checkpoint at 80% — leaving 20% allows the agent to complete the current step and deliver coherent partial results
- Partial results are valuable — a well-documented partial completion is more useful than a truncated full attempt
- Report budget status regularly — don't hide cost from the human; cost transparency enables better task design
- When a step is 2-3x more expensive than estimated, surface it immediately rather than letting it exhaust the budget silently
