# Two-Reviewer Agent Pattern

## What It Solves

A single agent that both implements and reviews its own work has a systematic bias: it reviews the implementation it produced, not the implementation the spec required. The implementer's mental model of what the code should do bleeds into the review.

The two-reviewer pattern uses separate agents for separate concerns, which eliminates this bias and catches two different categories of errors.

## The Three-Agent Chain

```
Implementer agent → Spec-compliance reviewer → Code-quality reviewer
```

**Implementer**: Reads task + spec, writes the code. No review responsibility.

**Spec-compliance reviewer**: Reads original task + spec + implementation. Asks ONLY: "Does the implementation do what was asked?" Does NOT evaluate code quality — only correctness against requirements.

**Code-quality reviewer**: Reads implementation only (not the original spec). Asks ONLY: "Is this code correct, secure, and maintainable?" Does not re-evaluate spec compliance.

The split is critical. A combined reviewer conflates "did it do what was asked" with "is the code good." These are different questions that require different reference material.

## When to Use

Use the two-reviewer pattern when:
- Task involves auth changes (spec compliance = right system; quality = no security holes)
- Task involves billing or data mutations (spec compliance = correct amounts/targets; quality = no race conditions)
- Task produces a component another agent will consume (spec compliance = correct interface; quality = correct implementation)
- Any task where "looks right" and "is right" could diverge

Skip for:
- Mechanical string replacements
- File renames
- Copy-only content tasks with no logic

## Prompt Structure

### Implementer prompt
```
TASK: [full task description]
SPEC: [exact requirements]
OUTPUT: Write the implementation only. Do not explain or review.
RULES: [project-specific constraints]
```

### Spec-compliance reviewer prompt
```
You are a spec compliance reviewer. You will NOT evaluate code quality.

ORIGINAL TASK: [exact task description]
ORIGINAL SPEC: [exact requirements]
IMPLEMENTATION:
[paste implementation]

Your only question: Does this implementation fulfill the stated requirements?
- List each requirement
- For each: PASS or FAIL with one sentence explanation
- Overall: COMPLIANT or NON-COMPLIANT

Do not suggest improvements. Do not evaluate style or structure.
```

### Code-quality reviewer prompt
```
You are a code quality reviewer. You will NOT evaluate spec compliance.

IMPLEMENTATION:
[paste implementation]
PROJECT RULES: [corrections-log content]

Check only:
1. Security: any exposed secrets, SQL injection, XSS, auth bypass
2. Type safety: unhandled nulls, missing error handling at system boundaries
3. Performance: N+1 queries, blocking operations on the main thread
4. Maintainability: names that don't describe intent, logic that requires comments to understand

Output: ISSUES FOUND or CLEAN, with specific line references for any issues.
```

## Critical Rule: Never Cross-Brief the Reviewers

Do NOT tell the spec-compliance reviewer about code quality concerns. Do NOT tell the code-quality reviewer what the original spec said. Cross-briefing collapses the separation and reintroduces the bias.

If the spec-compliance reviewer notices a quality issue: they log it as a note, not a compliance failure. If the code-quality reviewer notices a spec violation: they flag it as out-of-scope and surface it separately.

## Parallel vs Sequential

Run the two reviewers in **parallel** if you want speed. Run them **sequentially** (spec compliance first) if you want the quality reviewer to skip sections that already failed compliance review.

Parallel is almost always the right choice unless the spec compliance failure rate is high (>30%), in which case sequential avoids quality-reviewing code that will be rewritten anyway.

## Handling Conflicts

When spec reviewer says COMPLIANT and quality reviewer says ISSUES:
→ Fix the quality issues, re-run quality review only

When spec reviewer says NON-COMPLIANT and quality reviewer says CLEAN:
→ Re-implement, then run both reviewers again

When both say issues:
→ Re-implement from scratch — the implementer fundamentally misread the task

## Tracking Review Outcomes

In session-trajectory.md, log review outcomes:

```
REVIEW: spec COMPLIANT, quality ISSUES → fixed lines 23, 47 → re-reviewed CLEAN
```

This creates a record of what implementation errors occurred, which feeds the corrections-log and improves future prompts.
