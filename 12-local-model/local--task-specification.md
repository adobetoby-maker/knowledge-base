# Local Model Task Specification

## Why Specification Matters More for Local Models

Cloud models tolerate ambiguous prompts — they infer intent, ask clarifying questions, and self-correct. Local models are more literal and have less capacity for inference. An underspecified prompt produces generic or wrong output.

The rule: **specify what you want, what constraints apply, and what the output format must be.**

## Task Specification Template

```
## Context
[What project/file/system this task applies to]
[What the current state is]
[What existing code/patterns to follow]

## Goal
[Exactly what should exist or change when the task is done]
[NOT: "improve the code" — YES: "add a function that calculates the total for an invoice array"]

## Constraints
[What must NOT change]
[What libraries/patterns to use]
[What libraries/patterns to avoid]

## Output Format
[Exact format expected: TypeScript function, JSON object, SQL migration, etc.]
[Where the output goes: specific file path]
[What surrounding code to preserve]
```

## Example: Well-Specified Task

```
## Context
Working in: /Users/drive/jrs-auto-repair/lib/invoices/calculate.ts
Current state: function calculateInvoiceTotal() exists but doesn't handle discounts

## Goal
Add a function applyDiscount(total: number, discount: Discount): number
Where Discount = { type: 'percent' | 'flat'; value: number }
- 'percent' discount: reduce by value% (e.g., value=20 → multiply by 0.8)
- 'flat' discount: subtract value (e.g., value=15 → subtract $15)
- Never return a negative number (minimum 0)

## Constraints
- Do NOT modify calculateInvoiceTotal() 
- Use TypeScript strict mode (no 'any')
- Export the new function

## Output Format
TypeScript function to add to lib/invoices/calculate.ts
Place after the existing calculateInvoiceTotal function
```

## Example: Under-Specified Task (Problematic)

```
// BAD: too vague
"Add discount support to the invoice system"

// Local model problems:
// - Doesn't know which file to edit
// - Doesn't know the existing types
// - Might modify wrong functions
// - Output might not be TypeScript
// - Might create a whole new file instead of adding to existing
```

## Breaking Down Compound Tasks

Complex tasks should be broken into single-responsibility steps:

```
// BAD: compound task
"Add a new invoice feature with database migration, API endpoint, and UI component"

// GOOD: sequential single steps
Step 1: "Write SQL migration to add discount_amount column to invoices table"
Step 2: "Update Invoice type in lib/types.ts to include discount_amount?: number"
Step 3: "Update calculateInvoiceTotal in lib/invoices/calculate.ts to use discount_amount"
Step 4: "Add discount_amount field to the invoice form component"
```

Each step has clear input (previous step's output) and clear output (a specific artifact).

## Referencing Existing Code

Always show the existing function signature or interface when asking a local model to extend it:

```
## Context
Existing type in lib/types.ts:
\`\`\`typescript
export interface Invoice {
  id: string
  number: string
  status: 'pending' | 'paid' | 'overdue'
  total: number
  customer_id: string
  created_at: string
}
\`\`\`

## Goal
Add discount_amount?: number to the Invoice interface.
Also add a DiscountType = 'percent' | 'flat' type.
```

Without the existing code, the model might change fields, use different types, or add incompatible properties.

## Output Verification Specification

For each task, specify how to verify success:

```
## Verification
Run: npx tsc --noEmit
Expected: no TypeScript errors
If errors: the most likely issue is [specific thing to check]

Also run: npx vitest run lib/invoices/calculate.test.ts
Expected: all 5 tests pass
```

Include specific verification commands so the model (or a verification agent) can check its own output.

## Batch Task Manifest

For overnight batch jobs, a manifest file specifies all tasks:

```json
{
  "tasks": [
    {
      "id": "task-001",
      "description": "Add applyDiscount function to calculate.ts",
      "file": "lib/invoices/calculate.ts",
      "requiresFiles": ["lib/invoices/calculate.ts", "lib/types.ts"],
      "outputFile": "lib/invoices/calculate.ts",
      "verifyCommand": "npx tsc --noEmit && npx vitest run lib/invoices/calculate.test.ts",
      "dependsOn": [],
      "priority": 1
    },
    {
      "id": "task-002",
      "description": "Update Invoice interface to include discount_amount",
      "file": "lib/types.ts",
      "requiresFiles": ["lib/types.ts"],
      "outputFile": "lib/types.ts",
      "verifyCommand": "npx tsc --noEmit",
      "dependsOn": [],
      "priority": 1
    }
  ]
}
```

Tasks with no `dependsOn` can run in parallel. Tasks with dependencies must run sequentially.
