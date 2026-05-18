# Corrections Log — Living Rule File

**What this is:** Every time the AI makes a mistake on this codebase, one rule gets added here. Over time this becomes the most valuable file in the system — a precise record of what went wrong and what to do instead.

**Concept credit:** Harness Engineering (Mitchell Hashimoto / Hermes project) — transform AI from a confused newcomer into a seasoned team member through accumulated correction.

**Rule format:** One mistake → one rule. Specific, testable, actionable.
---

## Auth Rules

**Rule A1:** Never use `verifyAdminSession()` in jrs-auto-repair — that function doesn't exist. The correct function is `verifyAdmin()` from `lib/adminAuth.ts`.

**Rule A2:** Never use `supabase.auth.getSession()` for security checks. Use `supabase.auth.getUser()` — getSession trusts the client-controlled cookie and can be spoofed.

**Rule A3:** In Next.js 15+, `cookies()` returns a Promise. Always `await cookies()` before calling `.getAll()` or `.set()`.

## Project Structure Rules

**Rule P1:** jrs-auto-repair blog is at `/blog`, NOT `/articles`. The route is `app/blog/`, not `app/articles/`.

**Rule P2:** Blog content in jrs-auto-repair lives in `lib/articles.ts` as TypeScript objects. Never create markdown files for articles — they won't be picked up.

**Rule P3:** language-lens-elite is NOT Next.js. It's TanStack Start (React Router v7 + Vite). Never use `next/image`, `next/link`, or any `next/*` imports in that project.

**Rule P4:** manage-worker-bee auth is deliberately disabled. Do not try to add auth checks — it's an open internal tool by design.

## Supabase Rules

**Rule S1:** `admin.ts` Supabase client (using service role key) is NEVER imported client-side. It bypasses all RLS policies.

**Rule S2:** When Supabase query returns empty and you expect data, check RLS first — not the query. A silent empty result usually means no matching policy, not bad SQL.

**Rule S3:** `.single()` throws PGRST116 when 0 rows returned — this is not an error in the query, it means no row matched. Use `.maybeSingle()` when 0 results is acceptable.

## Cloudflare Workers Rules

**Rule C1:** Cloudflare Workers V8 isolates do not have Node.js. Never use `fs`, `path`, `crypto` (Node version), or `process.env`. Use `env` parameter and `globalThis.crypto`.

**Rule C2:** KV is eventually consistent. Never rely on reading a value immediately after writing it in the same Worker execution.

## Next.js Rules

**Rule N1:** `force-dynamic` prevents static rendering but does NOT fix module-level code that runs at build time. Use lazy init pattern for that.

**Rule N2:** Never use `getServerSideProps` or `getStaticProps` in App Router. Those are Pages Router APIs. App Router uses async Server Components.

**Rule N3:** `params` in App Router routes is a Promise in Next.js 15+. Always `await params` before accessing `params.slug`, `params.id`, etc.

---
## How to Use This File
- Load this file at the start of every session
- When a mistake is found and corrected, add a rule here immediately
- Use format: `**Rule [A/P/S/C/N/R][number]:** [what not to do] — [what to do instead]`
- Categories: A=Auth, P=Project, S=Supabase, C=Cloudflare, N=Next.js, R=React, G=General
