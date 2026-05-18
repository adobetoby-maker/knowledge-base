# Agent Pattern: Result Verification

## Overview
Agents assume success silently. A file write might fail silently, a command might exit 1 while the agent continues, an API response might contain an error payload the agent doesn't check. Explicit result verification after every step — read back what you wrote, check exit codes, inspect API responses — prevents incorrect intermediate results from propagating through the rest of the task.

## Implementation

### File Write Verification
After writing a file, verify its content:
```
Writing src/api/invoices.ts...
[file write]

Verifying write...
[read src/api/invoices.ts]
✓ File written correctly — confirmed 127 lines, createInvoice function present
```

For critical files, verify specific content:
- Check that the function signature matches what was intended
- Check that imports resolve to existing paths
- Check that exports match what consuming files expect

### Command Execution Verification
After running a command, check exit code and output:
```bash
npm run build
# → Exit code: 0 ✓
# → Output: "Compiled successfully in 8.2s" ✓

npm run typecheck
# → Exit code: 1 ✗
# → Error: "src/api/invoices.ts(47): error TS2345: Argument of type 'string' is not assignable to parameter of type 'number'"
# → Action: fix the type error before proceeding
```

Don't proceed to the next step after a non-zero exit code.

### API Call Verification
After calling an external API:
```typescript
const response = await stripe.invoices.create(params);

// Verify — don't assume success
if (response.status !== "draft") {
  throw new Error(`Expected invoice status 'draft', got '${response.status}'. Params: ${JSON.stringify(params)}`);
}
// ✓ Invoice created: id=in_1234, status=draft
```

### Database Query Verification
After a write query, verify the write:
```typescript
const result = await db.insert(invoices).values(data).returning();

// Verify the row was actually inserted
if (result.length === 0) {
  throw new Error("Invoice insert returned no rows — check RLS policies or constraints");
}
// ✓ Invoice inserted: id=uuid-1234
```

### Verification Depth by Risk
Not every step needs full verification — calibrate by consequence:

**High risk (verify fully):**
- Database writes (especially deletes/updates)
- File writes to production config files
- API calls with real-world effects (send email, charge card)
- Auth or permission configuration changes

**Medium risk (spot-check):**
- New code files — check that imports compile, exports exist
- Multi-file refactors — check the first and last file, spot-check middle

**Low risk (trust, verify on failure):**
- Comment changes, formatting updates
- Adding new constants to an existing file

## Key Rules
- Never assume a write succeeded — read it back for any critical operation
- Check command exit codes explicitly — output that looks like success can accompany a non-zero exit
- For API calls, check the response payload, not just the HTTP status — a 200 response can contain an error in the body
- When verification fails, stop immediately — don't attempt step N+1 based on a broken step N result
- Verification adds overhead — calibrate depth by consequence, not habit
- For long-running tasks, verification at each step catches errors before they compound into rework
- The fastest path to the wrong result is skipping verification after each step
