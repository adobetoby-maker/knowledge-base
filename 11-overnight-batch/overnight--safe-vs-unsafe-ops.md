# Overnight — Safe vs Unsafe Operations

**When:** Any autonomous session where no human is available to approve actions.
**Rule:** Only perform safe operations. Log unsafe operations to NEEDS_HUMAN.md and continue.

## ALWAYS SAFE (do without asking)
```
File Operations:
  ✅ Read any file
  ✅ Create new files
  ✅ Edit existing files
  ✅ Create new directories
  ✅ Rename files (with git mv to preserve history)

Git:
  ✅ git status, git diff, git log
  ✅ git add specific files
  ✅ git commit (to current branch)
  ✅ git push to non-main branches
  ✅ git checkout -b new-branch-name

Build / Test:
  ✅ npm install
  ✅ npm run build
  ✅ npm run test
  ✅ npm run lint
  ✅ npx tsc --noEmit

Research:
  ✅ Web search, URL fetch, documentation lookup
  ✅ Memory search
  ✅ Read codebase files

Supabase (read-only):
  ✅ list_tables, list_migrations
  ✅ execute_sql with SELECT only
  ✅ get_logs, get_advisors
  ✅ generate_typescript_types
```

## REQUIRES HUMAN APPROVAL (log and skip)
```
Git:
  ❌ git push to main/master
  ❌ git reset --hard
  ❌ git clean -f

Files:
  ❌ rm, delete, unlink
  ❌ Overwriting .env files

Database:
  ❌ apply_migration (irreversible schema change)
  ❌ execute_sql with DELETE, DROP, TRUNCATE
  ❌ Modifying production data

External:
  ❌ Sending iMessages or emails
  ❌ Creating GitHub PRs (unless explicitly instructed)
  ❌ Deploying to production (preview is OK)
  ❌ Any paid API calls with unknown volume (crawls, etc.)

Services:
  ❌ Cancelling or deleting Vercel deployments
  ❌ Deleting Supabase projects, tables, or buckets
  ❌ Modifying DNS or domain settings
```

## The Gray Zone (use judgment)
```
Supabase execute_sql with INSERT/UPDATE:
  → Safe if it's seeding test data with clear intent
  → Unsafe if it modifies user data or production records
  → DEFAULT: log to NEEDS_HUMAN.md

Creating a GitHub PR:
  → Safe if the task explicitly said to create a PR
  → Unsafe if you're inferring the user wants one
  → DEFAULT: push branch, log PR creation to NEEDS_HUMAN.md

Installing new npm packages:
  → Safe if the package is well-known and the need is clear
  → Log new packages added in the session summary
```
