# Code Review Checklist

## Pre-Review: Understand the Change

Before evaluating code quality:
1. Read the task description or PR summary
2. Understand what the code is supposed to do
3. Identify what system(s) it touches

The most common review failure is evaluating code against imagined requirements rather than actual requirements.

## Security Checks (Block if Failed)

```
[ ] No secret keys, API keys, or passwords in code
[ ] User input is validated with Zod or equivalent at every API boundary
[ ] Auth check present on every Route Handler that accesses data
[ ] No admin.ts Supabase client imported in client components
[ ] No SQL string concatenation with user input
[ ] NEXT_PUBLIC_* variables contain nothing sensitive
[ ] Service role operations are gated behind admin auth, not user auth
```

If any security check fails: block the PR. Security issues are not "nice to fix" — they ship to production.

## Auth Correctness (Block if Wrong System)

```
[ ] /admin/* routes use verifyAdmin (admin cookie), not Supabase auth
[ ] /portal/* routes use supabase.auth.getUser(), not verifyAdmin
[ ] No mixing of the two auth systems in the same route
[ ] getUser() used for security checks (not getSession())
```

## Data Access

```
[ ] Supabase queries include user_id = user.id scope (defense-in-depth, even with RLS)
[ ] No .single() calls without handling PGRST116 (no rows found)
[ ] Error objects checked, not ignored ({ data, error } → check error)
[ ] No unauthenticated writes to user-owned data
```

## Next.js / React Correctness

```
[ ] 'use client' not added unnecessarily (Server Components render faster)
[ ] Async Server Components handle errors (try/catch or notFound())
[ ] params awaited: const { slug } = await params (Next.js 15+)
[ ] Dynamic imports used for heavy client components with browser APIs
[ ] No getServerSideProps or getStaticProps (App Router doesn't use these)
```

## TypeScript Quality

```
[ ] No 'as any' casts without justification
[ ] No 'as SomeType' casts that mask actual type checking
[ ] Error objects typed (catch (error: unknown) → instanceof Error check)
[ ] Optional chaining used where nullability is expected (?.)
[ ] No non-null assertions (!) without verified reason
```

## Code Readability

```
[ ] Functions do one thing (< 40 lines as a guideline, not a rule)
[ ] Variable names describe what they hold, not how they're computed
[ ] No comments explaining what the code does (only WHY if non-obvious)
[ ] No dead code (commented-out blocks, unused imports, unused variables)
[ ] Complex conditions extracted to named variables
```

## Testing (Required for Business Logic)

```
[ ] Pure functions in lib/ have unit tests
[ ] API routes have tests for: happy path, auth failure, invalid input
[ ] New Supabase tables have RLS policy tests
[ ] Edge cases covered: empty arrays, null values, max lengths
```

## Performance (Fail if Degrading)

```
[ ] No N+1 queries (loop with database call inside → use JOIN instead)
[ ] Images use next/image with dimensions (prevents CLS)
[ ] Heavy components dynamically imported (not in the initial bundle)
[ ] No console.log statements left in production code
```

## Giving Review Feedback

Severity labels for review comments:
- **BLOCK:** Security issue or correctness bug that must be fixed before merge
- **FIX:** Non-security bug or important code quality issue
- **SUGGEST:** Improvement that would be better but is not blocking
- **NOTE:** Observation that doesn't require action

Use these labels explicitly so the author knows what needs to happen before merging.

## Self-Review Before Requesting Review

Before requesting a review from anyone else:
1. Read the diff as if you've never seen it
2. Run through this checklist yourself
3. Run `npm run build` and `npx tsc --noEmit` — zero errors/warnings
4. Test the primary flow and at least one error case
