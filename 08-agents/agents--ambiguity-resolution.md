# Agent Pattern: Ambiguity Resolution

## Overview
Almost every real task specification contains ambiguities. An agent that asks clarifying questions for every ambiguity is slow and annoying. An agent that resolves all ambiguities silently buries wrong interpretations. The balance: resolve obvious ambiguities with a stated interpretation, flag blocking ambiguities explicitly, and proceed with documented assumptions rather than stopping work.

## Implementation

### Ambiguity Classification

**Obvious — resolve and note:**
Ambiguity where one interpretation is clearly the most sensible given context.
```
AMBIGUITY: "update the invoice" — interpreted as updating the line items and recalculating totals.
  If only the status field should change, see the updateInvoiceStatus() function instead.
```

**Non-blocking — resolve with workaround and note:**
Ambiguity that affects behavior but has a sensible default.
```
AMBIGUITY: "send a confirmation email" — unclear which template to use.
  Using the existing 'invoice_created' template. If a different template is needed,
  update the templateId in api/invoices.ts line 94.
```

**Blocking — surface and stop:**
Ambiguity where either interpretation would produce significantly different code and neither is clearly correct.
```
BLOCKING AMBIGUITY: "delete the invoice" — unclear if this means:
  (a) Hard delete: remove from database permanently
  (b) Soft delete: set deleted_at timestamp, retain data
  
  The rest of the codebase uses soft deletes for users but hard deletes for drafts.
  Cannot proceed without clarification — the DB schema and all queries differ between options.
```

### Format: Ambiguity Log
For tasks with multiple ambiguities, log them all before starting:
```
## Ambiguity Log

1. [OBVIOUS] "format the amount" → formatted as "$49.99" (dollar sign, two decimal places, comma separator for thousands)
2. [NON-BLOCKING] "notify the customer" → using email only, not SMS. Add SMS if Twilio is integrated.
3. [BLOCKING] "apply the discount" → unclear if discount applies before or after tax.
   → Stopping here. Please clarify: should discount reduce taxable amount or be applied to final total?
```

### Decision Rule for Obvious Ambiguities
Resolve without asking when:
- One interpretation is consistent with how similar things work in the codebase
- One interpretation is consistent with the task description's context
- The wrong interpretation would be caught quickly by a test or type error
- Fixing the wrong interpretation would take < 5 minutes

Surface for clarification when:
- Both interpretations could silently produce wrong data (especially financial, auth, or security-related)
- The interpretations require fundamentally different schemas or architectures
- The task says "make sure" or "ensure" — the standard is implied but unstated

## Key Rules
- Write "AMBIGUITY:" as a literal prefix — makes it scannable and distinct from implementation notes
- State your interpretation explicitly: not just "I chose A" but "I chose A because X, and if B is correct, change Y"
- Never silently pick an interpretation for a blocking ambiguity — silent wrong choices are the hardest to find
- Group ambiguities together at the start of the output, don't scatter them across the implementation
- For non-blocking ambiguities, implement the resolution in a way that makes it easy to change (constant, config, comment) rather than hardcoded
- When a task produces unexpected output, review the ambiguity log first — most "bugs" are resolved ambiguities that were resolved wrong
