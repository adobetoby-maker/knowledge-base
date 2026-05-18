# Review: Code Review Antipatterns

## Overview
Code review is one of the highest-value engineering practices, but it can also become a source of
friction, gatekeeping, and team dysfunction when done poorly. The antipatterns below are common
ways code review goes wrong — not in the code being reviewed, but in the review process itself.
Recognizing them is the first step to running reviews that improve code quality without damaging team morale.

## Implementation

### Antipattern: Style Wars
```
✗ What it looks like:
  "I prefer camelCase here"
  "This should use a ternary instead of if/else"
  "Two blank lines between functions, not one"

  Result: 20-comment review about formatting, zero about logic.

✓ Fix: Automate style decisions
  - ESLint + Prettier handle formatting — reviewers must not override automated style decisions
  - Agree on a config once, commit it, never discuss it again in reviews
  - If a style choice isn't worth adding to the linter, it's not worth a review comment
```

### Antipattern: Nitpick-Only Reviews
```
✗ What it looks like:
  Every comment is a minor suggestion (variable names, comment wording, import order)
  Zero acknowledgment of what the PR does well
  No comments on architecture, correctness, or edge cases

  Result: Author feels their work was not understood, only inspected for flaws.
  Large, risky PRs get the same feedback as simple ones.

✓ Fix:
  - Open with what the PR accomplishes and what you verified
  - Group comments by severity: blocking (must fix) vs suggestion (optional)
  - Use prefix labels: "nit:", "suggestion:", "question:", "blocking:"
  - Match depth of review to risk of change
```

### Antipattern: Blocking Over Preference
```
✗ What it looks like:
  "I would have done this with a Map instead of an object" — then requesting changes
  "This approach works, but I'd prefer to see it differently" — blocking merge
  Reviewer substitutes their taste for the author's judgment on non-correctness issues

  Fix: Ask yourself:
  - Is this wrong? (incorrect behavior, bug, security issue) → blocking
  - Is this a genuine quality issue? (performance, maintainability) → blocking with explanation
  - Is this different from how I would have done it? → suggestion, not a block
```

### Antipattern: Reviews Without Rationale
```
✗ What it looks like:
  "Change this" (no explanation)
  "This is wrong" (no explanation of why)
  "Use X instead" (no explanation of the benefit)

  Result: Author can't learn or evaluate the feedback. Creates guessing games.

✓ Fix: Every suggestion needs a "because":
  "Move this outside the loop → avoids creating a new regex on every iteration"
  "Use an index here → this query runs without one, which will cause table scans on large datasets"
  "This mutation should be in an action, not an effect → effects are for synchronizing with external systems"
```

### Antipattern: Reviewing Too Fast
```
General guidance: 500 lines of code should take 45-90 minutes to review seriously.
Speed = lines / 10 minutes is a review in name only.

Signs of a too-fast review:
  - Comments only on the first file (reviewer got tired)
  - No comments on business logic, only on syntax
  - Review completed in < 5 minutes for a 300-line PR

What "reading the PR" means:
  1. Understand the problem being solved (read the description)
  2. Trace the data flow end-to-end
  3. Check edge cases manually
  4. Look for what's NOT there (missing error handling, missing tests, missing migration)
```

### Antipattern: Large PRs Reviewed Without Feedback on Scope
```
✗ What it looks like:
  2000-line PR gets approved with "LGTM"
  Reviewer felt overwhelmed, approved to unblock the author

✓ Fix: Feedback on the PR structure is valid review feedback
  "This PR is too large to review safely — can we split the migration from the feature?"
  "I've reviewed the core logic; the test changes need a separate pass"
  
  It is better to split a large PR than to approve code that wasn't actually reviewed.
```

### Antipattern: No Praise
```
✗ What it looks like:
  Only negative comments — nothing about what was done well
  "fixed" and "changed" as the only outcomes

✓ Why praise matters:
  - Reinforces good patterns so they recur
  - Establishes psychological safety for the review relationship
  - Calibrates the author: knowing what you did RIGHT is as valuable as knowing what to fix

  "This error handling pattern is much cleaner than the old approach — good call."
  "Nice use of the discriminated union here — I hadn't thought to use that for this."
```

## Key Rules
- Never discuss style in code review — automate it with ESLint and Prettier
- Prefix every comment with intent: "blocking:", "nit:", "suggestion:", "question:", "praise:"
- If you would not add it to the linter config, reconsider whether it belongs in the review
- Reviews take time proportional to risk — a 500-line PR touching auth deserves 2+ hours, not 10 minutes
- Blocks should always explain WHY the current approach is problematic — not just what to do instead
- Large PR scope is valid feedback — it is never LGTM-ing a 2000-line PR you didn't really read
- Every PR review should have at least one thing the reviewer found well done
