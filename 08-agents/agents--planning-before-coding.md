# Agent Pattern: Planning Before Coding

## Overview
Starting to write code immediately — without a plan — is the primary cause of wasted agent turns. An agent that writes 10 files and then discovers it chose the wrong architecture must undo all of it. A 2-turn planning phase catches wrong approaches, missed files, and conflicting edits before they happen, saving 10+ rework turns on complex tasks.

## Implementation

### The Plan Format
Before writing any code, output a structured plan:

```
## Plan

**Approach:** [One sentence describing the architectural approach and why]

**Files to change:**
- `src/api/invoices.ts` — add bulk create endpoint, validate with Zod, return array of Invoice
- `src/db/invoices.ts` — add `bulkInsert()` method using transaction
- `src/types/invoice.ts` — add `BulkInvoiceInput` type
- `src/api/invoices.test.ts` — add test for bulk create, 422 on validation failure

**Files NOT changing:** (prevents scope creep)
- `src/auth/` — no auth changes needed, existing middleware covers this
- `src/db/migrations/` — schema is already correct

**Open questions:**
- Max batch size limit? (Assuming 50 unless told otherwise — will note in code)
- Should partial success be allowed (some invoices fail, others succeed)? (Assuming all-or-nothing transaction)

**Risks:**
- The existing `insertInvoice()` function uses a singleton connection — need to verify it supports transactions before extending it
```

### When to Plan

Plan before coding when:
- Task involves more than 3 files
- The approach has more than one viable option
- The task involves a database schema change or migration
- The task touches auth, payment, or other sensitive systems
- The requirements contain ambiguity that affects the architecture

Skip planning for:
- Single-file changes with a clear, obvious implementation
- Bug fixes where the affected code is already identified
- Renaming, reformatting, or other mechanical changes

### Plan Review
After outputting the plan, wait for confirmation or corrections before starting implementation. If operating autonomously (no human in the loop), write the plan to a `PLAN.md` file in the working directory, then proceed — the plan serves as a checkpoint if the task needs to be resumed.

## Key Rules
- Output the plan as text before writing any code — not as a comment in the first file
- List every file that will be changed, including test files
- Explicitly list files that will NOT change — prevents scope creep
- State assumptions inline with the plan, labeled "ASSUMPTION:" — assumptions about requirements, not implementation details
- If the plan reveals the task is larger than expected, surface that immediately rather than discovering it mid-implementation
- A plan is not a contract — revise it when you learn new information mid-implementation, but note the revision
- For tasks taking more than ~20 code edits, break the plan into phases and implement one phase at a time
