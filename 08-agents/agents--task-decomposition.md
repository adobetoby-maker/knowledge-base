# Agent Task Decomposition

## Why Decompose Tasks

Large tasks have a higher failure rate. A single agent asked to "build the entire invoice feature" will either:
1. Take so long the context window fills and loses track
2. Make assumptions that break things downstream
3. Rush the later parts after spending too much context on early parts

Decomposed tasks fail in smaller, isolated ways that are easier to fix.

## Decomposition Strategies

### By Layer (Most Common)

Separate tasks by architectural layer:
```
Task 1: Database schema — create invoices table, RLS policies, indexes
Task 2: Data layer — lib/invoice-db.ts with CRUD functions
Task 3: Business logic — lib/invoice-calculations.ts (tax, totals)
Task 4: API — app/api/invoices/route.ts  
Task 5: UI — app/portal/invoices/page.tsx + components
Task 6: Tests — test the calculation functions
```

Each task is independently completable and verifiable.

### By Feature Component

For features that have distinct user-facing parts:
```
Invoice feature decomposition:
  - Create invoice (form + save)
  - View invoice list
  - View invoice detail
  - Edit invoice
  - Delete invoice
  - Send invoice email
  - Download invoice PDF
```

Start with the most critical (create + view). Test before building auxiliary features (send, download).

### By Risk Level

Order tasks by risk, low-risk first:
```
1. Add new database column (additive, safe)
2. Update TypeScript types (compile-time check)
3. Update data access layer
4. Update UI to use new field
5. Remove old code (risky — do last, verify nothing breaks)
```

## The Dependency Graph

Before decomposing, identify dependencies. Tasks should flow from least-dependent to most-dependent:

```
DB schema → Types → Data layer → Business logic → API → UI → Tests
```

Never start a task that depends on an incomplete prior task. Always verify each layer before starting the next.

## Parallel vs Sequential

Some tasks can run in parallel (no shared dependencies):

```
Sequential (must be ordered):
DB schema → Supabase types → TypeScript interface → API → UI

Parallel (independent):
  Branch A: Admin invoice creation (different UI than portal)
  Branch B: Email notification for invoice
  Branch C: PDF generation
  All can be built simultaneously after API is complete
```

## Task Sizing

Good task size: completable in one AI session, testable by running the code.

Too large:
```
"Implement the complete billing system with Stripe integration, 
invoice management, email notifications, and PDF downloads"
```

Too small:
```
"Add the word 'Invoice' to the page title"
```

Right size:
```
"Create the invoice creation form with customer name, line items, 
and total calculation. Form should submit via Server Action and 
redirect to the invoice detail page on success."
```

## Task Handoff Format

When one agent finishes a task and the next needs to continue:

```markdown
## Completed: Invoice Database Schema

### What was done
- Created `invoices` table with columns: id, user_id, number, customer_name, total, status, created_at
- Created `line_items` table with FK to invoices
- Added RLS policies: users can read/write their own invoices
- Added indexes on user_id and status

### Files created/modified
- Supabase migration: 20260518_invoices.sql (applied)
- lib/types/invoice.ts — TypeScript types for Invoice, LineItem

### What's ready for next task
The next task (API layer) can now:
- Use `supabase.from('invoices')` with the new schema
- Import `Invoice`, `LineItem` types from `lib/types/invoice.ts`

### Blockers / Notes
- Line items don't have a tax field yet — add if tax-per-item is needed
```

This handoff format ensures the next agent has all context without re-reading everything.

## Failure Recovery in Pipelines

When a task in a pipeline fails:
1. Don't skip ahead — later tasks depend on the failed one
2. Log the failure with specifics (what failed, what was expected)
3. Try a different approach to the same task (not a different task)
4. If truly blocked, log to NEEDS_HUMAN.md and halt the pipeline

The pipeline is as strong as its weakest step. Fix failures before proceeding.
