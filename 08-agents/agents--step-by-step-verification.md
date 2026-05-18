# Agent Pattern: Step-by-Step Execution with Verification Gates

## Overview
For risky multi-step tasks — database migrations, deploys, data transformations, permission changes — executing all steps at once amplifies mistakes. A wrong step 2 that isn't caught until step 8 means undoing 6 steps, some of which may be irreversible. Verification gates between steps catch problems while they're still cheap to fix.

## Implementation

### Structure: Execute → Verify → Proceed

For each step:
1. Announce what you're about to do
2. Execute the step
3. Verify the result
4. Only proceed to step N+1 if step N verified correctly

```
## Step 1: Add database column

About to: ALTER TABLE invoices ADD COLUMN tax_rate DECIMAL(5,4) NOT NULL DEFAULT 0.0;

[Execute migration]

Verifying step 1:
→ Running: SELECT column_name, data_type, column_default FROM information_schema.columns 
           WHERE table_name='invoices' AND column_name='tax_rate'
→ Result: tax_rate | numeric | 0.0000 ✓

Step 1 complete. Proceeding to step 2.

---

## Step 2: Backfill existing rows

About to: UPDATE invoices SET tax_rate = 0.08 WHERE state = 'CA' AND tax_rate = 0.0;
Estimated rows affected: 1,247

[Execute backfill]

Verifying step 2:
→ Running: SELECT COUNT(*) FROM invoices WHERE state='CA' AND tax_rate = 0.0
→ Result: 0 rows remaining (backfill complete) ✓
→ Running: SELECT COUNT(*) FROM invoices WHERE state='CA' AND tax_rate = 0.08
→ Result: 1,247 rows (matches expected) ✓

Step 2 complete. Proceeding to step 3.
```

### When to Use Verification Gates

**Always use gates for:**
- Database migrations (schema changes, backfills)
- Deploys to production
- Bulk data modifications
- Permission or role changes
- Deleting or archiving records
- Any step that is difficult or impossible to undo

**Skip gates for:**
- Reading-only operations (no side effects)
- Operations within a transaction that will be rolled back on failure
- Development/local environment where mistakes are cheap

### Gate Criteria (What Counts as "Verified")

Each step needs a specific verification criterion defined before execution:

| Step | Verification criterion |
|---|---|
| Add column | `SHOW COLUMNS FROM table` includes new column with correct type |
| Deploy | Health check endpoint returns 200, error rate unchanged |
| Backfill | `SELECT COUNT(*) WHERE old_condition = 0` (nothing left to update) |
| Add permission | User with the role can perform the newly permitted action |
| Create file | File exists at expected path with non-zero size |

### Failure Handling at Gate
```
Step 3 verification FAILED:
→ Expected: all 5,000 users have billing_email set
→ Found: 247 users still have NULL billing_email

Options:
1. Re-run the backfill for the remaining 247 (may have been added after backfill ran)
2. Make billing_email nullable (change the constraint in step 4)
3. Investigate why these 247 users have no email before proceeding

Stopping here. Do not proceed until this is resolved.
```

## Key Rules
- Define the verification criterion for each step BEFORE executing — don't define success retroactively based on what you see
- A step is not "done" until verified — "executed" and "done" are different states
- When a gate fails, stop completely — do not continue to the next step with unverified state
- Verification should test the actual outcome, not just that the command ran without error
- For bulk data operations, verify both the modification (correct rows changed) and the non-modification (incorrect rows untouched)
- The cost of verification gates is 10-20% extra time; the cost of discovering a mistake at step 8 in a 10-step process is 100% rework
