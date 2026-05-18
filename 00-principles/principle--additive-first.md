# Additive-First Principle

## Core Rule

When solving a problem, prefer adding to the existing system over modifying or replacing existing parts. The default question should be: "Can I add something to make this work?" rather than "What do I need to change?"

This is a risk management principle. Adding is generally safer than modifying because:
- Adding doesn't break existing functionality
- Adding is easier to revert (just remove the addition)
- Modifying can have unexpected side effects on callers

## Practical Applications

### Adding a new field to a TypeScript type

```typescript
// Instead of: change 'status' type
interface Invoice {
  status: 'pending' | 'paid'  // was this, need to add 'refunded'
}

// Do: extend the union (additive)
interface Invoice {
  status: 'pending' | 'paid' | 'refunded'
}
```

### Adding a column to a database table

```sql
-- Instead of: modifying the 'status' column type
-- Do: add a new column if backward compatibility matters
ALTER TABLE invoices ADD COLUMN refund_amount decimal(10,2);

-- Only modify existing column when all consumers are updated simultaneously
```

### Adding a route instead of changing an existing one

When a route needs behavior change that might break existing callers:
1. Add `/api/v2/endpoint` with the new behavior
2. Migrate callers to the new route
3. Deprecate and eventually remove the old route

### Adding an optional parameter

```typescript
// Old signature
async function sendEmail(to: string, subject: string, html: string)

// Additive extension — backward compatible
async function sendEmail(to: string, subject: string, html: string, options?: EmailOptions)
```

Callers using the old signature still work. No migration needed.

## When to Modify Instead of Add

The additive approach has limits. Modify existing code when:
- The existing code is incorrect and must be fixed (bugs are always fixes, not additions)
- The addition would create duplication that becomes a maintenance burden
- The existing interface is fundamentally wrong for the new requirement
- Performance requires replacing, not adding (adding a faster path alongside a slow one is wasteful)

## The Danger Zone: Premature Addition

The additive principle can go wrong when applied mindlessly:
- Adding a new function when a one-line fix to the existing function would do
- Adding `v2` routes when the `v1` route could be safely updated
- Adding a field to handle a case that belongs in a different object

When "add" means adding tech debt, the right choice is to fix the root cause.

## Database Migration Additive Pattern

For tables with existing data, always add before changing:

```sql
-- Step 1 (additive): add new column as nullable
ALTER TABLE invoices ADD COLUMN new_status text;

-- Run data migration

-- Step 2 (modify): make column required after backfill
ALTER TABLE invoices ALTER COLUMN new_status SET NOT NULL;

-- Step 3 (remove): drop old column after all code is updated
ALTER TABLE invoices DROP COLUMN old_status;
```

Each step can be rolled back independently. Never combine all three into one migration.
