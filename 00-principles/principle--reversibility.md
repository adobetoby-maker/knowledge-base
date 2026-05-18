# Reversibility Principle

## Core Rule

Before taking an action, ask: can this be undone? The harder it is to reverse, the more caution required before proceeding.

This principle governs when to act autonomously vs when to pause and confirm.

## Reversibility Spectrum

**Fully reversible — act freely:**
- Create a file (can be deleted)
- Edit a file (git history preserves old version)
- Push to a feature branch (can be reverted)
- Create a database record (can be deleted)
- Add a column to a table (can be dropped)
- Deploy to preview/staging

**Reversible with effort:**
- Rename a file (break imports, but fixable)
- Change a function signature (updates callers, but findable)
- Merge a branch (can be reverted, but creates noise)
- Add a non-nullable column (requires migration strategy)

**Hard to reverse:**
- Delete a file (no git history if untracked)
- Drop a database table (data gone unless backup exists)
- Force push to main (remote history rewritten)
- Push to npm/PyPI (package versions are immutable)
- Send an email (cannot unsend)
- Delete a deployment (DNS/CDN cache persists)

**Irreversible:**
- Delete a production database without backup
- Remove a Cloudflare Worker (traffic drops immediately)
- Revoke API keys that services depend on

## The Branch-First Strategy

When in doubt about a destructive operation, branch first:

```bash
# Instead of: making changes directly on main
git checkout -b fix/remove-deprecated-endpoint

# Make the changes
# If it looks right, merge
# If wrong, delete the branch (main is untouched)
```

Applied to database: add a new column alongside the old one, migrate data, then drop the old column after all code is updated. Never modify the column directly.

## NEEDS_HUMAN.md Protocol

When an operation is irreversible and you're operating autonomously, log it and stop:

```markdown
# NEEDS_HUMAN.md

## Blocked Operations

### 2026-05-18 14:30 — Database drop required
**Action needed:** Drop `old_status` column from `invoices` table
**Why blocked:** Destructive — data loss if column has values we haven't migrated
**Context:** Added new `status` column, code migrated. `old_status` now unused.
**To complete:** Verify no active data in old_status → `SELECT COUNT(*) FROM invoices WHERE old_status IS NOT NULL` → run DROP COLUMN
```

## Application to Database Operations

```sql
-- Additive: safe, reversible
ALTER TABLE invoices ADD COLUMN new_status TEXT;

-- Destructive: confirm first
ALTER TABLE invoices DROP COLUMN old_status;  -- PAUSE, confirm before running

-- Never combine in one migration
-- Step 1 (safe): ADD COLUMN, deploy code that writes to it
-- Step 2 (risky): DROP COLUMN — only after code no longer references old column
```

## Application to Code Deletions

Before deleting a file or function:
1. Check if anything imports or calls it: `grep -r "functionName" --include="*.ts"`
2. Check git blame to understand why it was added
3. If it has active callers, don't delete — fix the callers first
4. If safe to delete, do it in a separate commit from the feature work

## The Rollback Plan

For any non-trivial change, have a rollback plan before deploying:

| Change | Rollback |
|--------|---------|
| New API endpoint | Delete route file, redeploy |
| Schema migration | Write and test down migration before running up migration |
| New feature flag | Turn off flag |
| Package upgrade | `npm install package@previous-version` |
| Vercel deployment | Vercel dashboard → promote previous deployment |

"I don't know how to roll this back" is a signal to not deploy yet.
