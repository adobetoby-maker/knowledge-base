# Principle: Documentation Proximity

## Overview
Documentation that lives far from the code it describes decays faster than the code itself. A wiki page written at feature launch is stale six months later when the code changes but the wiki page is not updated. Documentation adjacent to the code — in the same repository, in the same directory, or inline in the same file — is seen by engineers during the natural course of working on the code. Proximity creates the conditions for documentation to stay accurate.

## The Decay Principle

Documentation accuracy is inversely proportional to its distance from the code:

| Location | Update discipline required | Typical accuracy after 6 months |
|---|---|---|
| Inline comment (in the function) | Low — right in front of you | High |
| File header comment | Low — visible when opening file | High |
| README in same directory | Moderate | Moderate |
| `docs/` folder in same repo | Higher | Moderate-Low |
| Confluence / Notion wiki | High (separate tool, separate workflow) | Low |

## Where Documentation Lives

### Package/Module README
Every package with its own `package.json` or directory gets a `README.md`:
```
packages/
  payments/
    README.md      ← what this package does, how to use it, key decisions
    index.ts
  notifications/
    README.md
    index.ts
```

### ARCHITECTURE.md (Repository Root)
System-level decisions: what are the major components, how do they communicate, what are the data flows, what are the scaling constraints. This is for new engineers on day one.

### Architecture Decision Records (ADRs)
Every significant architectural decision gets an ADR: what was the decision, what alternatives were considered, why was this chosen, what are the known trade-offs. Stored in `docs/decisions/` or `adr/`:
```
docs/decisions/
  001-use-postgres-over-dynamodb.md
  002-event-sourcing-for-orders.md
  003-tanstack-start-over-nextjs.md
```

ADRs are append-only. If a decision changes, write a new ADR that supersedes the old one. The old ADR stays — it captures why a decision was made, which is still valuable history.

### Inline Comments for Non-Obvious WHY
Code should explain what it does through good naming. Comments explain why code exists in a non-obvious form:

```typescript
// Wrong: explains what the code does (the code already does that)
// Divide total by 100 to get dollars
const dollars = cents / 100;

// Right: explains why the code is written this way
// Stripe returns amounts in the smallest currency unit (cents for USD).
// We store amounts as cents throughout the system to avoid floating point
// errors, converting only at display time.
const displayPrice = (cents: number) => (cents / 100).toFixed(2);

// Right: explains a non-obvious constraint
// We must process events in batches of max 10 because the downstream
// webhook service has a payload size limit of 256KB and each event
// averages 25KB. See incident #247 for context.
const BATCH_SIZE = 10;
```

### CHANGELOG.md
A running log of significant changes, in reverse chronological order, aimed at consumers of the package or API. Generated from commit messages or maintained manually. Required for any package with external consumers.

## Documentation As Part of the Feature

Documentation updates are part of the definition of done for every feature, not a follow-up task:

- New feature → update `README.md` in the affected package
- Architectural decision → write an ADR
- Breaking API change → update `CHANGELOG.md` + API documentation
- Non-obvious code → add inline comment at the time of writing, not later

"We'll document it later" means it will never be documented.

## Key Rules
- Every package directory has a `README.md`
- Repository root has `ARCHITECTURE.md` for new-engineer orientation
- ADRs for every decision where "why wasn't X chosen?" would be a reasonable question
- Inline comments for non-obvious WHY, never for obvious WHAT
- Wiki pages are for content that truly has no code home (team processes, oncall guides)
- Documentation PRs require the same review as code PRs — they are equally important
- When code changes, the PR description calls out which docs were updated
