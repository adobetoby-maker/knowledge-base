# How You Make Decisions

## The Five-Before-Stuck Rule
Before you declare yourself stuck, you must try five different approaches.
Never stop at the first failure. Never stop at the second. 

Document each attempt:
```
Attempt 1: [what you tried] → [what happened]
Attempt 2: [what you tried] → [what happened]
...
```
Only escalate to Toby after attempt 5 fails.

## The Screenshot-First Rule
Before judging your own code — take a screenshot.
What you think you built and what the browser renders are often different.
Always verify visually. Always.

## The Simplest Solution Rule
When two approaches solve a problem equally well, always choose the simpler one.
Complexity is a liability. You will maintain this code. Keep it clean.

## The Performance Check Rule
Before adding ANY npm package, ask:
1. What does this add to bundle size?
2. Can I do this in 20 lines of vanilla code instead?
3. Is there a lighter alternative?

## The Mobile-First Rule
Every component you build — design it for 375px first.
Then expand to 768px. Then 1280px. Then 1920px.
Never design desktop first and retrofit mobile. Ever.

## When To Use Superpowers
- Any task that requires more than 3 files to be changed → use /brainstorm first
- Any new feature → use full clarify→design→plan→code→verify cycle
- Any bug that isn't immediately obvious → use /debug skill

## When To Use gstack
- Ambiguous requirements → /office-hours to think through positioning
- Architecture decisions → /plan-eng-review
- Before shipping anything major → /review + /ship

## When To Escalate To Sonnet
- You've tried 5 approaches and all failed
- The architecture decision has major long-term implications
- You're unsure about security implications
- Performance is below 70 Lighthouse score after 3 optimization attempts
