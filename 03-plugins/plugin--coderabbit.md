# Plugin: coderabbit

**What it provides:** PR-style code review with deep analysis — similar to having a senior engineer review every diff.
**Key agent:** `coderabbit:code-reviewer`

## When to Use
- Reviewing a completed feature before merging
- Getting a comprehensive review of a large diff
- When you want line-level feedback with suggested fixes
- Before client delivery of a finished feature
- Want a second opinion separate from your own analysis

## vs Other Review Agents
```
/review (gstack)              → quick sanity check, 5-10 issues max
feature-dev:code-reviewer     → convention + quality focus, project-aware
coderabbit:code-reviewer      → deep PR-style review, line-by-line, most thorough
ruflo-core:reviewer           → security focus + confidence filtering
pr-review-toolkit suite       → comprehensive: tests, types, silent failures, comments
```

Use `coderabbit:code-reviewer` when: you want the most thorough analysis and are willing to wait for it. It's slower but surfaces more issues than a quick review.

## Usage
```typescript
Agent({
  subagent_type: "coderabbit:code-reviewer",
  prompt: "Review all changes in the feature/promo-banner branch.
           Focus on: functionality, security, performance, and code quality.
           Report issues by file with line numbers, severity (critical/major/minor), 
           and specific fix suggestions."
})
```

## What It Checks
- Logic errors and edge cases
- Security vulnerabilities (injection, auth bypass, data exposure)
- Performance issues (unnecessary re-renders, missing indexes, N+1 queries)
- Code style and maintainability
- Missing error handling
- TypeScript type safety
- Test coverage gaps

## Review Output Format
coderabbit returns reviews in structured format:
```
## src/components/PromoBanner.tsx

**Line 12 — Major**: localStorage.setItem called without try-catch. 
localStorage throws in private browsing mode and when storage is full.
Fix: wrap in try-catch.

**Line 28 — Minor**: Magic string 'promo_dismissed' repeated 3x.
Fix: extract to const PROMO_KEY = 'promo_dismissed'.
```

## Pairing with Feature Dev
Best practice: finish implementation → coderabbit review → address P0/P1 findings → merge.
```typescript
// After implementing
Agent({ subagent_type: "coderabbit:code-reviewer", prompt: "Review..." })
// Address critical and major findings
// Merge when only minor/informational remain
```
