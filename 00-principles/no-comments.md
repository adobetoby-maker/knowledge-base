# No Comments Unless the WHY Is Non-Obvious

**When:** Any time you're about to write a code comment.
**Rule:** Default is no comment. Only add one when the WHY is non-obvious: a hidden constraint, a subtle invariant, a workaround for a specific bug, behavior that would surprise a reader.

## The Test
Ask: "If a good developer reads this code a year from now with no context, would this comment prevent confusion?"
Yes → write it. No → skip it.

## What Warrants a Comment
```typescript
// Supabase module-level init crashes at build time — lazy init defers to runtime
let _client: SupabaseClient | null = null

// Safari doesn't support backdrop-filter without -webkit prefix
backdrop-filter: blur(12px);
-webkit-backdrop-filter: blur(12px);

// Cloudflare Workers don't support Node.js crypto — using Web Crypto API
const hashBuffer = await crypto.subtle.digest('SHA-256', encoded)
```

## What Does NOT Warrant a Comment
```typescript
// Set user name  ← obvious from the code
setUserName(value)

// Check if logged in  ← obvious
if (!user) return null

// Increment counter  ← obvious
count++

// Returns the user's email  ← the function name already says this
function getUserEmail(user: User): string { return user.email }
```

## Docstrings / Multi-Line Comments
Never write multi-paragraph docstrings. One short line max.
The function name + TypeScript types already describe the what and the shape.
The only missing thing is the why — and that's usually one sentence.

## The "Added For X" Anti-Pattern
Never write comments that reference the current task, fix, or caller:
```typescript
// Added for the signup flow  ← rots as code evolves
// Fixed issue #123  ← belongs in git commit, not the code
// Used by AuthProvider  ← callers change; this becomes a lie
```
These belong in the git commit message, not the file.
