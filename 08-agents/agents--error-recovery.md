# Agent Error Recovery Patterns

## Types of Errors Agents Encounter

1. **Tool failure** — a tool call returns an error (file not found, API rate limit, permission denied)
2. **Unexpected state** — the system is in a state the agent didn't anticipate (file exists when expecting empty)
3. **Ambiguity** — the task can't be completed without information not provided
4. **Irreversible action blocked** — the next required step is destructive and needs confirmation

## Recovery Pattern 1: Read-Verify-Retry

Before assuming a tool failed, verify the current state:
```
1. Attempt the operation
2. If it fails, READ the current state
3. Compare actual state to expected state
4. If already in desired state, continue (idempotent — success)
5. If in unexpected state, diagnose before retrying
6. Retry once with corrected approach
7. If still failing, surface to human with specific diagnosis
```

Example:
```
Attempt: Write file at /app/components/Invoice.tsx
Error: "File has not been read yet"

Recovery:
1. Read /app/components/Invoice.tsx
2. If file exists with content: it was already written — treat as success, continue
3. If file is empty or different: now re-write with Edit tool
```

## Recovery Pattern 2: Checkpoint Before Destructive Operations

Before any operation that's hard to reverse, save state:
```typescript
// lib/migration-safety.ts
async function safeRun(operation: () => Promise<void>, backupFn: () => Promise<void>) {
  // Create backup
  await backupFn()
  
  try {
    await operation()
  } catch (error) {
    // Restore from backup
    console.error('Operation failed, backup created:', error)
    throw error
  }
}
```

For database migrations:
1. Create a NEEDS_HUMAN.md if the next step is a DROP TABLE or DELETE
2. Include: what state the system is in, what the next step would be, the exact SQL to run

## Recovery Pattern 3: NEEDS_HUMAN File

When an agent encounters an unrecoverable situation without human input, create a file:

```markdown
# NEEDS_HUMAN — 2026-05-18 10:30:00

## What I Was Doing
Adding a NOT NULL column `customer_email` to the `invoices` table as part of feature X.

## Where I Got Stuck
The migration requires backfilling existing rows before adding the NOT NULL constraint.
There are 1,247 existing invoices with no customer email — I cannot determine the correct email
without querying customer records that don't exist in this project.

## What Needs to Happen
1. Decide: should existing invoices use a placeholder email, or should the column be nullable?
2. If placeholder: run `UPDATE invoices SET customer_email = 'legacy@placeholder.com' WHERE customer_email IS NULL`
3. If nullable: change the migration to `customer_email TEXT` (no NOT NULL)

## Files Modified So Far
- supabase/migrations/0012_add_customer_email.sql — created but NOT yet applied

## To Resume
After deciding, apply the migration and tell the agent to continue from step 4 of the original task.
```

## Recovery Pattern 4: Partial Completion Tracking

For long multi-step operations, track progress so recovery is possible:
```typescript
// progress.json (created at start of batch job)
{
  "task": "generate 50 SEO articles",
  "total": 50,
  "completed": 23,
  "failed": [12, 18],
  "last_completed_at": "2026-05-18T03:22:15Z"
}
```

On recovery, read the progress file and skip already-completed items:
```typescript
const progress = JSON.parse(fs.readFileSync('progress.json', 'utf-8'))
const remaining = allItems.filter((_, i) => 
  i >= progress.completed && !progress.failed.includes(i)
)
```

## Recovery Pattern 5: Fallback Strategies

When the primary approach fails, have a fallback:
```typescript
async function getArticleContent(url: string): Promise<string> {
  // Primary: fetch full article
  try {
    const res = await fetch(url)
    return await res.text()
  } catch {
    // Fallback 1: try cached version
    try {
      return await getCachedContent(url)
    } catch {
      // Fallback 2: return minimal content for the AI to work with
      return `[Article at ${url} could not be fetched. Generate based on URL context.]`
    }
  }
}
```

## When NOT to Recover Automatically

Stop and surface to human when:
- The error involves financial data or user PII
- Recovery would require guessing user intent
- The operation is irreversible (deleting data, sending emails)
- Two consecutive retries have failed with the same error
- The system is in a state that contradicts what the task assumed (e.g., task says "add column X" but column X already exists with different constraints)

## Error Context to Include When Surfacing

When an agent stops and reports an error, include:
```
1. The exact error message (not paraphrased)
2. What tool was being called with what parameters
3. What the state is now (did any partial changes happen?)
4. The specific question that needs human decision
5. Two or three options the human can choose from
```

## Diagnosing Before Retrying

Wrong approach: retry the same call three times hoping it succeeds
```
// Anti-pattern
for (let i = 0; i < 3; i++) {
  try { return await doOperation() } catch { continue }
}
```

Right approach: read the current state, understand why it failed, adjust:
```
1. Operation failed with "row not found"
2. Query the database to check if the row exists
3. If it doesn't exist: the data assumption was wrong — surface to human
4. If it does exist under different ID format: adjust the query and retry once
```
