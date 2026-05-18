# AI Regression Blind Spots — The 4 Repeated Mistakes

## What This Is

These are not random errors. These are systematic failure modes that AI assistants make repeatedly across sessions because:
1. They have no memory of previous attempts
2. They have training biases toward certain "obvious" solutions
3. They optimize for local coherence (this file looks right) over global correctness (this file breaks that one)

Understanding these patterns lets you write prompts and hooks that intercept them before they produce broken code.

---

## Blind Spot 1: Context Boundary Confusion

**The mistake:** Importing server-only modules in client components, or trying to use browser APIs in Server Components.

**Why it happens:** The model sees the import as syntactically valid and locally coherent. It does not track the bundle boundary across files.

**Canonical example:** Importing `lib/supabase/admin.ts` (service role) inside a client component. The file exists, the import path resolves — but it exposes the service role key to the browser.

**Detection signal:** Any import of `admin.ts`, `server.ts`, or anything using `SUPABASE_SERVICE_ROLE_KEY` in a file that has `'use client'` at the top.

**Prevention:** GateGuard check — "Is this Server Component or Client Component?" must be answered before first write.

---

## Blind Spot 2: Auth System Cross-Contamination

**The mistake:** Mixing admin cookie auth logic with Supabase JWT auth logic in the same function or route.

**Why it happens:** Both systems protect routes, so they seem interchangeable. The model uses whichever pattern appeared more recently in context.

**Canonical example:** A portal route (`/portal`) that uses `verifyAdmin()` (admin cookie) instead of checking Supabase session (JWT). The admin can access the portal but customer sessions are treated as unauthenticated.

**Detection signal:** Any route under `/portal` calling `verifyAdmin`; any route under `/admin` using Supabase session checks.

**Prevention:** Project-specific rule in corrections-log.md. Never apply one auth system's patterns to the other's routes.

---

## Blind Spot 3: Stale API Pattern Application

**The mistake:** Using a Next.js pattern from the Pages Router when working in the App Router, or using Next.js 13 patterns in Next.js 15+.

**Why it happens:** The model has extensive training data on older Next.js patterns. When a task looks similar to a familiar one, it reaches for the familiar implementation.

**Canonical examples:**
- `getServerSideProps` in an App Router project (does not exist)
- `params.id` instead of `await params` (params is a Promise in Next.js 15+)
- `router.push` inside a Server Component (no router in RSC)

**Detection signal:** Build-time errors like "getServerSideProps is not exported", type errors on `params.id`, runtime errors about using hooks in Server Components.

**Prevention:** Load the relevant version-specific file before writing code. Corrections rule N3: `params` is a Promise in Next.js 15+ — `const { id } = await params`.

---

## Blind Spot 4: RLS Silent Failure

**The mistake:** Writing a Supabase query that returns empty results and treating that as "no data" rather than "policy blocked this".

**Why it happens:** SQL empty results and RLS policy blocks look identical to application code — both return `{ data: [], error: null }`. The model logs "no records found" and moves on.

**Canonical example:** A query to `invoices` table returns empty. Model adds a "no invoices" empty state. Reality: RLS policy requires `user_id = auth.uid()` and the user is not authenticated in this context.

**Detection signal:** Unexpected empty results that work correctly when tested with the service role key but not the anon key.

**Prevention:** 
1. Always test queries with the exact auth context they'll run in (not service role)
2. When results are unexpectedly empty, check policies first: `SELECT * FROM pg_policies WHERE tablename = 'table_name'`
3. Never assume empty = no data; verify policy allows the query

---

## Using These in Prompts

When briefing an agent for any task touching these areas, name the relevant blind spot explicitly:

```
KNOWN FAILURE MODES FOR THIS TASK:
- This touches auth — confirm which system (admin cookie vs Supabase JWT) before editing
- This touches Supabase queries — if results are empty, check RLS policies before adding empty states
- This is an App Router project — getServerSideProps does not exist, params is a Promise
```

Naming the failure mode preemptively activates the model's ability to avoid it. Leaving it unnamed means the model defaults to its training prior, which produced the failure mode in the first place.

---

## Writing an AI Regression Test

For critical paths (auth, billing, data access), maintain a `regression-cases.md` file per project:

```
## RC-001: Portal auth
Given: /portal route
Expected: Supabase JWT check, redirects unauthenticated to /login
Failure pattern: verifyAdmin() called instead of session check

## RC-002: Invoice RLS
Given: SELECT from invoices for authenticated user
Expected: returns only that user's invoices
Failure pattern: returns empty [] when auth context is not set up
```

Before deploying any auth or database change, run through regression cases manually or via an agent review pass.
