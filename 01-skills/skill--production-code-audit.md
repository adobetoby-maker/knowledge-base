# Skill: production-code-audit

**Trigger:** Need a deep, systematic scan of an entire codebase for quality, security, performance, and maintainability issues before a major release or after inheriting a project.
**Invoke:** `/production-code-audit`
**Returns:** Multi-pass audit covering security, performance, dead code, architectural problems, and a prioritized fix list.

## When to Invoke
- Before launching a new client project
- After inheriting code from another developer
- Planning a major refactor
- Finding intermittent bugs that seem systemic
- Preparing for a security review
- Performance issues with unclear root cause

## What It Audits (the 7 passes)

### Pass 1 — Security
- Exposed secrets in code (API keys hardcoded)
- NEXT_PUBLIC_ variables that should be private
- SQL injection via unparameterized queries
- Missing auth checks on protected routes
- Missing input validation on API routes
- Cookie settings (httpOnly, secure, sameSite)
- CORS policy too permissive

### Pass 2 — Data Flow
- Supabase client used on wrong side (admin.ts imported client-side)
- useEffect with server data instead of TanStack Query
- State duplication between server and client
- Race conditions in async operations

### Pass 3 — Performance
- Images without width/height (layout shift)
- Missing `next/image` usage
- Heavy packages imported but not tree-shaken
- No caching on data-fetching routes
- Synchronous blocking operations

### Pass 4 — Dead Code
- Unused exports
- Console.log left in production paths
- Commented-out code blocks
- Unused env vars in .env

### Pass 5 — Type Safety
- `any` type usage (a hint at future bugs)
- Missing null checks before .property access
- Non-exhaustive switch statements
- Missing Zod validation at API boundaries

### Pass 6 — Architecture
- Business logic in components (should be in lib/)
- Fetch calls duplicated across components (should be shared)
- Components that exceed ~150 lines (should be split)
- Direct DB access from client components

### Pass 7 — Maintainability
- Magic strings and numbers (should be constants)
- Inconsistent naming conventions
- Files that don't follow project structure conventions

## Prioritization Output
Skill returns findings in three buckets:
- **P0 — Fix before deploy**: Security issues, data leaks, auth bypasses
- **P1 — Fix this sprint**: Performance, data integrity, UX-breaking bugs
- **P2 — Backlog**: Dead code, refactors, maintainability improvements

## What Skill Returns
Full audit results with file:line references, severity ratings, and specific fix recommendations for each finding.
