# Agent Pattern: Chain of Thought Prompting

## Overview
For complex reasoning tasks — architecture decisions, algorithm design, debugging tricky logic — requiring the agent to write out its reasoning before its conclusion measurably improves accuracy. The mechanism: writing forces sequential commitment that prevents the agent from jumping to a plausible-sounding but wrong answer. For simple lookup or mechanical tasks, CoT adds cost without benefit.

## Implementation

### Explicit CoT Prompt
```
Before writing any code, reason through the algorithm step by step:
1. What is the input format and edge cases?
2. What is the transformation required?
3. What is the output format?
4. What can go wrong?
Then write the code.
```

### Agent Output Structure with CoT
```
## Reasoning

**Input analysis:**
The function receives an array of invoice line items. Each item has `amount` (cents, integer) 
and `taxRate` (decimal, 0-1). The total must round correctly — I need to identify whether 
rounding happens per-line or on the total.

**Tax rounding decision:**
Per-line rounding: can cause $0.01 discrepancies due to multiple rounding operations.
Round-then-sum: avoids discrepancies but may not match how the customer computed the total.
Decision: round-then-sum (matches expected output in the test fixtures).

**Edge cases to handle:**
- Empty array → return 0, not NaN
- Items with taxRate = 0 → valid, just pass through amount
- Negative amounts (credits) → should reduce total

**Algorithm:**
```
total = sum(item.amount + Math.round(item.amount * item.taxRate))
return total (integer cents)
```

## Code
[implementation follows]
```

### When CoT Helps
Use CoT for:
- **Algorithm design**: sorting, pagination, tree traversal, graph problems
- **Debugging**: "why does this function return X when I expect Y"
- **Architecture decisions**: "should I use a webhook or a polling approach"
- **Security analysis**: "what could go wrong with this auth flow"
- **Complex SQL**: multi-join queries with aggregations and window functions

Skip CoT for:
- **Mechanical tasks**: rename a variable, reformat a block, add a comment
- **Lookup tasks**: "what's the syntax for this function call"
- **Simple CRUD**: standard create/read/update/delete endpoints with no tricky logic
- **Boilerplate generation**: scaffolding that follows a template

### Structured Reasoning Template
For debugging specifically:
```
Analyze the bug step by step:
1. What is the observed behavior?
2. What is the expected behavior?
3. What code path runs when the bug occurs?
4. What assumption in that code path is wrong?
5. What is the fix, and does it introduce any new issues?
```

## Key Rules
- The reasoning must come BEFORE the code — CoT works because it shapes the code generation, not because it documents it after the fact
- Don't force CoT on every task — it adds 30-50% tokens to the response; reserve it for tasks where accuracy matters more than speed
- Reasoning should identify the approach, not justify the chosen implementation — "I'm using a Map because lookup is O(1)" is useful; "I wrote this function as a function" is not
- If the reasoning reaches a conclusion that contradicts the task requirements, surface the contradiction explicitly before proceeding
- Short CoT (3-5 sentences) is better than long CoT for most tasks — verbose reasoning often circles back to the first instinct anyway
- For multi-step algorithms, CoT the whole approach before writing step 1 — don't interleave reasoning and code
