# Principle: Scope Creep Prevention

## Overview
Scope creep is not usually caused by malicious additions — it accumulates from a series of small, reasonable-seeming decisions made during implementation. Each "while I'm in there" addition shifts the real cost to future work: integration becomes harder, testing takes longer, and the delivery date slips without anyone having consciously decided to slip it. Discipline requires capturing requirements before coding starts and routing every change through an explicit decision.

## Implementation / Key Points

### Requirements Before Coding
Write acceptance criteria before writing any code. The act of writing them reveals ambiguity that would otherwise surface mid-implementation (the expensive moment). A simple template:

```
Feature: [Name]
Given: [initial state]
When: [user action]
Then: [expected outcome]
Error case: [what happens when X fails]
Out of scope: [explicitly list what this feature does NOT do]
```

The "Out of scope" section is the most important — it forces a conversation about boundaries before they're crossed.

### Change Decision Checklist
When a new idea surfaces during implementation, ask:
1. Was this in the original spec? If yes, build it.
2. Is it a blocker for the spec? If yes, escalate to scope a fix.
3. Is it a nice-to-have discovered during work? → Add to backlog, do not build now.
4. Is it a bug in existing behavior (not new work)? → Track separately.

Do not make this decision alone during implementation. Surface it in a check-in message or comment.

### Track Scope Additions with Impact
When a scope addition is approved, document it:
```
Scope Addition: [What]
Reason: [Why it's necessary]
Estimate impact: [+X hours / +Y days]
Approved by: [Name / Date]
Deferred alternatives: [What we're NOT doing to keep scope tight]
```

### "Nice to Have" List
Maintain a running list during the sprint. Every "while I'm in there" idea goes on the list. Review the list at the end of the sprint, not during it. Most items on the list will turn out to be lower priority than they seemed in the moment.

### Done = Original Spec Met
A feature is done when the original acceptance criteria are satisfied — not when there are no more improvements possible. "Better" is infinite; "done" is finite. The goal is a shipped feature with a known scope, not a perfect feature that ships late.

## Key Rules
- Requirements are written before a line of code is written.
- "While I'm in there" additions go to the backlog, not the current branch.
- Every scope change requires an explicit decision (not a silent addition) with an estimated impact.
- Out-of-scope items must be named explicitly in the requirements document.
- Done is defined by the original spec, not by the absence of further improvements.
- Track additions separately from the original work so you can measure how often scope expands.
