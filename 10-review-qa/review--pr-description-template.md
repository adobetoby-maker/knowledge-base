# Review: PR Description Template and Standards

## Overview
A PR description is documentation. It explains the "why" behind a change at the moment the author
understands it best — which is also the moment reviewers most need context to evaluate it correctly.
Good PR descriptions save review time, prevent misunderstandings, and serve as future reference
when someone runs `git log` asking why something changed.

## Implementation

### PR Description Template
```markdown
## What changed
One sentence. What does this PR do?
Example: "Adds rate limiting to the authentication endpoint to prevent brute-force attacks."

## Why it changed
Link to ticket/issue, or explain the business/technical reason.
Example: "Fixes #342 — users were able to make unlimited login attempts."
Or: "Performance degradation in production traced to N+1 query on the users index page."

## How to test
Step-by-step instructions a reviewer can follow to verify the change works.

1. Check out this branch
2. Run `npm run dev`
3. Navigate to `/login`
4. Enter wrong password 5 times
5. Verify: 6th attempt returns 429 with "Too many requests" message
6. Wait 60 seconds
7. Verify: can login again with correct credentials

## Screenshots (UI changes only)
Before: [screenshot]
After: [screenshot]

Include screenshots for: layout changes, new components, responsive behavior, dark mode.
Use GIFs for: animation, hover states, transitions.

## Migration notes (if DB schema changed)
- Adds `login_attempts` column to `users` table (nullable, default null)
- Migration is backwards compatible — no data backfill needed
- Migration: `20240315_add_login_attempts_to_users`

## Rollback plan (for high-risk changes)
If this causes issues in production:
1. Revert: `git revert HEAD` + deploy
2. The feature flag `RATE_LIMIT_ENABLED` can be set to `false` to disable without a deploy

## Checklist
- [ ] Tests added/updated
- [ ] No secrets in code
- [ ] Migration is backwards compatible
- [ ] Feature flag added for gradual rollout (if applicable)
- [ ] Documentation updated (if applicable)
```

### What Makes a Bad PR Description
```
✗ Empty body:
  Title: "Fix auth bug"
  Body: (empty)
  → Reviewer has no idea what broke, why it broke, or how to verify the fix

✗ Code description instead of change description:
  "Changed the timeout from 30s to 60s in lib/auth.ts line 47"
  → Describes WHAT changed, not WHY. A reviewer can see what changed in the diff.

✗ Ticket number only:
  "JIRA-1234"
  → Requires the reviewer to open another tab, log in to Jira, and read the ticket.
     Relevant context belongs in the PR.

✗ Vague why:
  "Improvements to auth"
  → What was wrong? What problem was this solving?
```

### Sizing Guidelines
```
Small PR (< 100 lines): 1-2 sentence description + test instructions are sufficient
Medium PR (100-400 lines): Full template required
Large PR (400+ lines): Full template + explanation of why this can't be split smaller
                        (or split it into multiple PRs)
```

### The "How to test" Section
```
This section exists because "it works on my machine" is not a review.
A reviewer should be able to follow the steps WITHOUT asking the author for help.

Include:
  - Setup steps (seed data, environment variables, feature flags)
  - Exact steps to reproduce the behavior being tested
  - What "success" looks like
  - What "failure" looks like (if the bug had a visible symptom)

For API changes:
  curl -X POST http://localhost:3000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email": "test@test.com", "password": "wrong"}' \
    # Expected: 401 {"error": "Invalid credentials"}
```

## Key Rules
- The "Why" section is mandatory — diffs show what changed, not why
- Link to the issue or ticket so there is a bidirectional reference
- Screenshots are required for any change that affects visible UI — they save more time than they cost
- "How to test" must be self-contained — a reviewer should not need to ask the author how to verify the change
- Document rollback plans for database migrations, infrastructure changes, and third-party integration changes
- Empty PR descriptions indicate the author did not take time to communicate — this is valid review feedback
- The PR title follows the same commit message convention: imperative mood, < 70 chars, no period
