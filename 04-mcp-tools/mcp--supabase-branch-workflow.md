# Supabase Branch Workflow

## What Branching Is

Supabase Branching creates a separate database environment for testing migrations and features. Each branch is an isolated copy of the schema with its own connection string.

Use branches for:
- Testing database migrations before applying to production
- Feature development that requires schema changes
- Reviewing schema changes in pull requests

## Creating a Branch

```
mcp__plugin_supabase_supabase__create_branch
{
  "project_id": "your-project-id",
  "branch_name": "feature/add-notifications"
}
```

Returns the branch ID and connection details.

## Applying Migrations to a Branch

Test migrations on the branch before production:
```
mcp__plugin_supabase_supabase__apply_migration
{
  "project_id": "branch-id",  // use the BRANCH project ID
  "migration_content": "ALTER TABLE invoices ADD COLUMN discount_amount NUMERIC(10,2) DEFAULT 0;"
}
```

## Listing Branches

```
mcp__plugin_supabase_supabase__list_branches
{
  "project_id": "your-production-project-id"
}
```

## Resetting a Branch

If a migration left the branch in a bad state:
```
mcp__plugin_supabase_supabase__reset_branch
{
  "branch_id": "your-branch-id"
}
```

This resets the branch schema to the production state.

## Merging a Branch to Production

After testing migrations on the branch:
```
mcp__plugin_supabase_supabase__merge_branch
{
  "branch_id": "your-branch-id"
}
```

This applies the branch's migrations to production.

## Deleting a Branch

After merging or if the branch is no longer needed:
```
mcp__plugin_supabase_supabase__delete_branch
{
  "branch_id": "your-branch-id"
}
```

## Connecting Your App to a Branch

For local testing with a branch, update `.env.local`:
```
NEXT_PUBLIC_SUPABASE_URL=https://branch-project-ref.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=branch-anon-key
SUPABASE_SERVICE_ROLE_KEY=branch-service-role-key
```

Revert to production values after testing.

## Branch Workflow for Migrations

Standard workflow for any schema change:
```
1. Create branch: mcp__plugin_supabase_supabase__create_branch
2. Apply migration to branch: mcp__plugin_supabase_supabase__apply_migration
3. Test with the branch connection string
4. If tests pass: mcp__plugin_supabase_supabase__merge_branch
5. If tests fail: mcp__plugin_supabase_supabase__reset_branch + fix migration
6. After merge: mcp__plugin_supabase_supabase__delete_branch
```

## Branch vs Direct Migration

| Scenario | Approach |
|---|---|
| Development (no existing users) | Apply directly with apply_migration |
| Staging/production with data | Always use branch first |
| Simple additive change (ADD COLUMN with DEFAULT) | Either is fine |
| Destructive change (DROP COLUMN) | ALWAYS branch first |
| Column type change | ALWAYS branch first |
