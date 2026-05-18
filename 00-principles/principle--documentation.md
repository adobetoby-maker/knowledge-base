# Documentation Principles

## What Gets Documented

Document decisions and non-obvious constraints, not mechanics. The codebase IS the documentation for what the code does. Documentation explains why it's done that way and what traps exist.

Document these things:
- **Architecture decisions** that aren't obvious from reading the code
- **Known gotchas** ("this must run before that", "don't use X — it breaks in Y environment")
- **Environment requirements** (which env vars are needed, what they're for)
- **Third-party quirks** (Supabase session refresh behavior, Cloudflare CPU limits)
- **Auth system topology** (which routes use which auth system, and why they were separated)

Skip documentation for:
- What a function does (the function name and types say that)
- Simple CRUD routes
- Standard framework patterns that any developer knows

## CLAUDE.md Files

`CLAUDE.md` at the project root is the primary documentation artifact. It's read by automated tools (including AI assistants). It must be:
- Kept up to date as architecture changes
- Specific enough to prevent the "wrong path" decisions
- Structured: commands, architecture, rules, gotchas

```markdown
# Project Name

## Commands
\`\`\`bash
npm run dev    # localhost:3000
npm run test   # vitest
\`\`\`

## Architecture
[Key decisions, not basic stack description]

## Critical Rules
- Rule 1: [what and why]
- Rule 2: [what and why]
```

## Inline Comments: When to Write Them

Write a comment ONLY when the WHY is not derivable from reading the code:

```typescript
// WRONG: narrates what the code does
// Check if user is authenticated
const user = await getUser()

// WRONG: explains obvious logic
// Return null if user doesn't exist
if (!user) return null

// RIGHT: explains non-obvious constraint
// getUser() re-validates the session against Supabase Auth server.
// getSession() only reads the cookie without re-validation — don't use it for auth checks.
const user = await getUser()

// RIGHT: explains why a workaround exists
// timingSafeEqual prevents timing attacks on HMAC comparison.
// String === would leak timing information about where strings differ.
if (!crypto.timingSafeEqual(sig, expectedSig)) {
  throw new Error('Invalid signature')
}
```

## Function Documentation

Only add JSDoc when:
- The function is part of a public API or shared library
- The parameters have non-obvious constraints

```typescript
// SKIP for internal utilities — the types are documentation enough
function formatCurrency(amount: number, currency = 'USD'): string {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(amount)
}

// ADD for shared utilities with edge cases
/**
 * Generates a deterministic hash for consistent percentage rollout.
 * Returns the same result for the same userId across all calls.
 * NOT cryptographically secure — only suitable for feature flags.
 */
function hashForRollout(userId: string): number {
  return userId.split('').reduce((acc, c) => acc + c.charCodeAt(0), 0) % 100
}
```

## README Files

`README.md` is for humans arriving at a repository for the first time. It should answer:
1. What is this? (one sentence)
2. How do I run it locally? (exact commands)
3. What do I need set up first? (env vars, external services)

Don't put architecture decisions in the README — those go in CLAUDE.md.

## Avoid These Documentation Anti-Patterns

**Comment rot**: Comments that don't match the code they describe:
```typescript
// Returns null if not found
// (but the code now throws — the comment lied)
function getInvoice(id: string): Invoice {
  const invoice = db.find(id)
  if (!invoice) throw new NotFoundError(id)  // comment is wrong
  return invoice
}
```

**Stale TODO comments**: TODOs without dates or owners become permanent fixtures:
```typescript
// TODO: add pagination (added 2023, never done, still here in 2026)
```

If it's real work, put it in Linear. If it's not important enough for Linear, delete the comment.

**Over-documenting tests**: Test names ARE the documentation. Don't add comments explaining what a test does — rename the test instead.

```typescript
// WRONG
// Tests that admin can delete any invoice
it('works', () => { ... })

// RIGHT
it('allows admin to delete invoices regardless of ownership', () => { ... })
```
