# Parallel Research Patterns

## When to Parallelize Research

Research tasks are parallelizable when they're independent — the answer to one doesn't affect what you'd ask in another.

Independent (can run in parallel):
- Checking documentation for library A and library B
- Reading files in different parts of the codebase
- Fetching data from two different APIs

Dependent (must run sequentially):
- Look up customer ID → then look up invoices for that customer
- Check if file exists → then read its content
- Get current schema → then write a migration

## Pattern 1: Parallel File Reads

When exploring a codebase, read related files simultaneously:
```
// Instead of:
Read lib/supabase/server.ts
Read lib/supabase/client.ts
Read lib/supabase/admin.ts

// Do in parallel:
Read [lib/supabase/server.ts, lib/supabase/client.ts, lib/supabase/admin.ts]
```

The total time is the maximum of the individual reads, not the sum.

## Pattern 2: Research Agent + Implementation Agent

Split work into independent research and implementation phases:
```
Phase 1 (parallel):
  Agent A: Read the current invoice schema from Supabase
  Agent B: Search for any existing invoice-related components in the codebase
  Agent C: Check current route structure for conflicts

Phase 2 (implementation, with Phase 1 results):
  Using all findings, implement the new invoice feature
```

## Pattern 3: Explore-Then-Build

For unfamiliar codebases, run exploration before writing any code:
```
Exploration agents (parallel):
  - Find all files mentioning "auth" 
  - Find all Route Handlers in the app
  - Read the CLAUDE.md for the project
  - Check package.json for relevant dependencies

Synthesis:
  - Review all findings together
  - Build a complete picture before touching any file
```

This prevents the "write code then discover a conflict" problem.

## Pattern 4: Fan-Out Data Gathering

When gathering data about multiple entities:
```typescript
// WRONG: serial
const invoice1 = await getInvoice('id-1')
const invoice2 = await getInvoice('id-2')
const invoice3 = await getInvoice('id-3')

// RIGHT: parallel
const [invoice1, invoice2, invoice3] = await Promise.all([
  getInvoice('id-1'),
  getInvoice('id-2'),
  getInvoice('id-3'),
])
```

Cap parallel concurrency for external APIs (batch in groups of 5-10 to avoid rate limits):
```typescript
// Process in parallel batches of 5
for (let i = 0; i < items.length; i += 5) {
  const batch = items.slice(i, i + 5)
  await Promise.all(batch.map(processItem))
  await new Promise(r => setTimeout(r, 1000))  // rate limit pause between batches
}
```

## Pattern 5: Parallel Verification

After making changes, verify multiple things simultaneously:
```
Verify (parallel):
  - TypeScript compiles without errors (tsc --noEmit)
  - Lint passes (eslint .)
  - Tests pass (vitest run)
  - Database schema matches expectations (execute_sql to inspect)
```

Don't wait for each in series — all four can check in parallel.

## Synthesizing Parallel Results

Parallel research produces multiple result sets. Synthesize before acting:
```
Research Results:
  - Agent A found: auth is in lib/auth.ts, uses getUser() 
  - Agent B found: 3 existing route handlers importing from lib/supabase/server.ts
  - Agent C found: /api/portal/* routes all call validatePortalSession()

Synthesis:
  - New route should: import from lib/supabase/server.ts AND call validatePortalSession()
  - Pattern is consistent across all existing portal routes — follow the same pattern
```

## What Makes Research Results Useful

For research agents to be useful, the prompt must specify:
1. **What to look for** (not just "explore the codebase")
2. **Where to look** (specific directories, patterns to search for)
3. **What format to return** (file paths, function signatures, SQL schemas)
4. **What decision the findings will inform** (so the agent knows what's relevant)

```
// Weak prompt:
"Research how auth works in jrs-auto-repair"

// Strong prompt:
"Read lib/adminAuth.ts and lib/supabase/server.ts in jrs-auto-repair.
Return: (1) the exact function signature of the admin validation function,
(2) the cookie name used for admin sessions,
(3) how the Supabase server client gets the user.
I need this to decide where to add auth to a new route handler."
```
