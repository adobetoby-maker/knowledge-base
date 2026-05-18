# Principle: Technical Debt Taxation

## Overview
Technical debt is not a metaphor — it compounds exactly like financial debt. Each piece of unaddressed debt makes every subsequent feature built on top of it slightly slower to deliver. A system with heavy technical debt has a "tax" on every sprint: the team pays it in slower velocity, more production bugs, longer debugging sessions, and developer attrition. The only way to reduce the tax is to pay down the principal, deliberately and continuously.

## Why Debt Compounds

When Debt A exists in the codebase and a new Feature B is built on top of Debt A:
- Feature B inherits Debt A's problems
- Feature C built on Feature B inherits both debts
- Refactoring Debt A now requires changing Features B and C

This is why debt that seems "harmless" in week 1 becomes a two-week project to fix in year 2. The debt's cost is not just the work to fix it — it is the tax paid on every feature built while it exists.

## Making Debt Visible

Debt that isn't tracked doesn't get paid. Every known piece of technical debt needs:

```typescript
// In code: comment + ticket number
// TODO(DEBT-247): This uses string comparison instead of enum because the
// legacy API returns inconsistent casing. Once the API is updated (tracked
// in DEBT-247), remove this .toLowerCase() normalization.
if (status.toLowerCase() === "pending") { ... }
```

The comment answers:
- What is the compromise?
- Why does it exist?
- What is the path to fixing it?
- Where is the backlog ticket?

Without a ticket number, the comment becomes noise that nobody acts on.

## The 20% Rule

Sustainable codebases dedicate 20% of engineering capacity to technical debt reduction. This is not negotiable or optional — it is how velocity is maintained over time. Teams that defer debt entirely see velocity halve within 18 months of moving fast. "We'll pay it back later" requires "later" to have a date on the calendar.

Practical implementation:
- One debt ticket per sprint in the sprint commitment
- "Tech debt Friday" — last day of sprint reserved for addressing accumulated small debts
- No feature can be built on top of known debt without first scheduling the debt's resolution

## Never Ship Knowing About a Bug Without a Ticket

Shipping with a known bug is acceptable (sometimes). Shipping with a known bug and no ticket is not. If you know about it and don't track it, it will never be fixed:

```
# Wrong: "It's a minor issue, we'll fix it eventually"

# Right:
1. Note the bug
2. Create a ticket with: observed behavior, expected behavior, severity, affected users
3. Triage: is this a P0 (ship blocker)? P1 (fix next sprint)? P2 (fix this quarter)?
4. Ship if P1 or P2, fix first if P0
```

## Debt Categories

**Code debt:** complex code that needs refactoring, missing abstractions, copy-paste duplication  
**Test debt:** missing test coverage for critical paths, flaky tests that are skipped  
**Infrastructure debt:** outdated dependencies with security CVEs, unsupported runtimes  
**Documentation debt:** missing runbooks, outdated ARCHITECTURE.md, undocumented APIs  
**Architecture debt:** wrong abstractions that require workarounds in every new feature  

Each category taxes the team differently. Architecture debt has the highest compounding rate.

## Dependency Upgrades Are Not Optional Debt

Unpinned dependency upgrades accumulate silently until a security CVE requires emergency action. The emergency upgrade is riskier than a planned upgrade because:
- No time for thorough testing
- Multiple major versions may have accumulated, each with breaking changes
- The team is operating under pressure

Planned approach: automated dependency PRs (Dependabot, Renovate) with weekly triage. Never let a dependency fall more than 2 major versions behind.

## Key Rules
- Every known debt has a `// TODO(TICKET-123):` comment and a corresponding ticket
- 20% of sprint capacity dedicated to debt — not negotiable with product
- Never build on top of debt without scheduling its resolution
- Known bugs ship only with a ticket; severity determines when the ticket is addressed
- Dependency upgrades are planned, not emergency patches
- When a debt is paid, delete the comment and close the ticket — visible progress matters for team morale
- Debt that cannot be quantified cannot be managed; estimate the cost of carrying it per quarter
