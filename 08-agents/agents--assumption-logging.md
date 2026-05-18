# Agent Pattern: Assumption Logging

## Overview
Every task specification has gaps. An agent that fills gaps silently produces output that looks correct but fails in ways that are hard to debug — because the failure mode is buried inside an assumption the reviewer never knew was made. Explicit assumption logging surfaces these gaps at the point where they can be cheaply corrected.

## Implementation

### Format
Label every assumption clearly in the output:

```
ASSUMPTION: The `users` table has a `deleted_at` column (soft delete pattern).
  → If this column doesn't exist, the query on line 47 will fail at runtime.
  → Alternative if using hard deletes: remove the WHERE clause filter.

ASSUMPTION: Concurrent invoice creation doesn't need to be serialized.
  → Multiple invoices for the same customer can be created simultaneously.
  → If serialization is required, add a row-level lock on the customer record.

ASSUMPTION: The existing API key auth middleware applies to this new endpoint.
  → Not adding explicit auth — relying on global middleware in middleware.ts.
```

### When to Log Assumptions

Log an assumption when:
- **File structure**: "ASSUMPTION: The DB client is exported from `lib/db.ts`" — if it's actually at a different path, the import fails
- **API contract**: "ASSUMPTION: The third-party webhook delivers JSON, not form-encoded data"
- **Business logic**: "ASSUMPTION: Refunds don't expire — once issued, always valid"
- **User intent**: "ASSUMPTION: 'update the invoice status' means just the status field, not recalculating line items"
- **Environment**: "ASSUMPTION: Redis is available at `process.env.REDIS_URL`"

Don't log obvious assumptions:
- Standard library behavior
- Language semantics
- Well-documented framework behavior

### Assumption Register (for long tasks)
For tasks with many assumptions, maintain a register at the top of the output:
```
## Assumptions Register
1. [HIGH RISK] DB uses soft deletes — `deleted_at` nullable timestamp
2. [MED RISK]  Email sending is fire-and-forget (no delivery confirmation)
3. [LOW RISK]  Invoice IDs are UUIDs (not sequential integers)
4. [LOW RISK]  All monetary amounts are in USD
```

Classify by risk:
- HIGH: wrong assumption makes the feature non-functional or data-corrupting
- MED: wrong assumption degrades behavior but doesn't break it completely
- LOW: wrong assumption is easy to fix if noticed

## Key Rules
- Write "ASSUMPTION:" as a literal prefix — makes it grep-able and visually scannable in long outputs
- State what the assumption is AND what breaks if it's wrong — the consequence is what makes it actionable
- Log assumptions at the point in the code where they matter, not just in a preamble — "this query assumes soft deletes" is most useful next to the query
- When a task produces surprising results, review the assumption log first — most bugs trace back to a wrong assumption
- If the same assumption appears in multiple places, extract it to a constant or config so it's only wrong in one place
- High-risk assumptions that can be verified (by reading a file, running a query) should be verified rather than assumed
