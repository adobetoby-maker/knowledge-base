# Technical Debt — Taxonomy and Paydown

Technical debt is not "messy code." That conflation leads to bad decisions — treating all rough edges as debt to be paid, while ignoring the structural problems that actually slow development down. Understanding the taxonomy is necessary for managing it.

## Debt Taxonomy

**Intentional debt** is a deliberate trade-off. You know the right design, you choose the shortcut, and you record why. "Using a polling loop instead of webhooks because the webhook infrastructure isn't ready yet — revisit after Q3 release." This is acceptable. It has a known shape, a known cost, and a known remediation path.

**Inadvertent debt** is discovered later. You wrote what seemed like reasonable code, and only through experience did you learn it was the wrong approach. This is unavoidable — some debt is the cost of learning. The failure mode is not incurring it; it's not recognizing it when you see it.

**Debt in wrong abstractions** is the most expensive kind. A module boundary that cuts across the domain wrong, a data model that encodes the wrong assumptions, a shared utility that has grown thirteen special-case flags — these require rethinking, not refactoring. Every line written on top of a wrong abstraction deepens the hole. Cleaning it up isn't "tidying the code"; it's a design change that touches everything built on it.

**Debt in messy code** is real but overrated. Inconsistent naming, duplicated logic, functions that are too long — these are expensive to read and easy to introduce bugs in. But they're tractable. You can pay them down file by file without touching the architecture. Don't conflate this with structural debt; they have very different remediation costs.

## Tracking Debt: The Rule of Visible Debt

Never accrue debt invisibly. When you make a deliberate trade-off, record it in code with a `TODO` or `FIXME` comment that includes:

1. **What the problem is** — not just "fix this," but why it's wrong
2. **What the right solution is** (even roughly)
3. **A ticket or issue reference** so it can be prioritized against other work

```ts
// TODO(PROJ-441): This calculates tax on the subtotal before discounts.
// Correct approach is to apply discounts first, then tax.
// Currently blocked on discount model refactor.
```

Without the ticket, the comment is a wish. Without the comment, the debt is invisible to the next developer. Both are required.

## Debt Accrual Signals

You're accruing debt when:
- You add a flag parameter to an existing function to handle a new case
- You duplicate a module because modifying the shared one would break other callers
- You add a `// this is fine for now` comment
- You skip writing tests because "it's just a quick fix"
- You hardcode a value because "we'll make it configurable later"

## Paydown Strategy

Prioritize debt that sits on **hot paths** — code that is changed frequently. Debt in stable, rarely-touched code is less urgent. Debt in code that everyone touches every day compounds at high interest.

Pay down structural/abstraction debt first when undertaking a refactor. Cleaning the messy code on top of a wrong abstraction is wasted work — you'll throw it away when you fix the structure.

Never schedule a "debt sprint." Debt paydown is most effective when woven into feature work — fix the debt in the module you're already modifying for a feature. Isolated debt sprints create a false sense of completion and usually tackle surface-level mess rather than structural problems.

## Key Rules

- Distinguish intentional debt (trade-off you chose) from inadvertent debt (mistake you discovered)
- Wrong abstractions are structural debt — the most expensive kind, requires rethinking not just tidying
- Never accrue debt invisibly: every deliberate shortcut gets a TODO with a ticket number and explanation
- Prioritize debt on high-churn code; stable rarely-touched code can wait
- Fix structural debt before cosmetic debt — cleaning messy code on a wrong foundation is wasted
- No dedicated debt sprints; pay debt down in the modules you're already changing
