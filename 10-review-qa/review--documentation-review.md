# Review: Documentation Review

## Overview
Documentation debt is invisible until someone joins the team, returns from vacation, or needs to debug a system at 2am. The most common documentation failure isn't bad writing — it's documentation that exists only in Slack threads, comments that say the wrong thing, or a README that describes a project from two years ago. The goal is documentation that lives with the code and stays accurate.

## Implementation / Key Points

### README Minimum Viable Content
A README passes review if it answers all of these for a new engineer:

```markdown
# Project Name

## What It Does
[2-3 sentences. What problem does it solve? Who uses it?]

## How to Run Locally
```bash
# Prerequisites
node 20+, pnpm

# Setup
pnpm install
cp .env.example .env  # fill in values from 1Password > project > dev

# Run
pnpm dev  # http://localhost:3000
```

## How to Test
```bash
pnpm test          # unit tests
pnpm test:e2e      # e2e tests (requires local dev server running)
```

## How to Deploy
[Link to deploy runbook, or brief steps]

## Contact / On-Call
[Team name, Slack channel, on-call rotation link]
```

If any section is missing, the README fails review.

### Architecture Decision Records (ADRs)
```markdown
# ADR-0012: Use Cursor Pagination Instead of Offset

## Status
Accepted — 2024-11-15

## Context
Orders table growing to 2M rows. Offset pagination causes full-table scans at page 500+.

## Decision
Switch all list endpoints to cursor-based pagination using `created_at` + `id` as cursor.

## Consequences
- Clients must store cursor, not page number
- Cannot jump to arbitrary page (acceptable — no use case requires this)
- Performance: constant time vs O(n) for offset
```

ADRs answer "why does the code work this way?" years later. Write one for every decision that isn't obvious from the code itself. Store in `docs/adr/` in the repo.

### Comment Quality
```typescript
// Bad: restates the code (adds no information)
// Multiply price by quantity
const total = price * quantity;

// Bad: stale (contradicts current code)
// Uses USD only
const formatCurrency = (amount: number, currency = 'USD') => { ... };

// Good: explains WHY — the business reason behind non-obvious behavior
// Tax is applied before discount per accounting team decision (2024-Q2)
// See: https://notion.so/internal/tax-policy-decision
const afterTax = applyTax(price);
const final = applyDiscount(afterTax);
```

Stale comments are worse than no comments — they actively mislead. Delete comments that describe what the code does. Keep comments that explain non-obvious decisions.

### API Documentation (at the route)
```typescript
/**
 * GET /api/orders
 * 
 * Returns paginated list of orders for the authenticated customer.
 * 
 * Query params:
 *   cursor: string — opaque cursor from previous response
 *   limit: number — max 100, default 20
 * 
 * Response:
 *   { data: Order[], nextCursor: string | null }
 * 
 * Errors:
 *   401 — not authenticated
 *   422 — invalid cursor format
 */
```
API documentation belongs at the route definition, not in a separate wiki. If the code moves, the documentation moves with it.

### No Documentation in Slack
Slack messages are unsearchable after 90 days (on free plan) and invisible to anyone who joins later. Every Slack thread that reaches a decision or contains important context should be distilled to:
- A comment in code
- An ADR
- README update
- An issue comment

### Documentation Review Checklist
- [ ] README: what it does, local setup, test command, deploy steps, contact
- [ ] ADR for every major architecture decision
- [ ] No comments that restate code
- [ ] No stale comments that contradict current code behavior
- [ ] Route-level documentation for all public API endpoints
- [ ] Environment variables documented in `.env.example` with explanations
- [ ] Runbooks exist for all operational procedures
- [ ] No critical process documented only in Slack

## Key Rules
- README must answer: what it does, how to run it, how to test it, how to deploy it — missing any one of these fails the review
- ADRs preserve the "why" — write one for every non-obvious decision, including what alternatives were rejected
- Comments that restate what code does add noise; comments that explain why code works a certain way add value
- Stale comments are worse than no comments — they actively mislead future maintainers
- Delete stale comments; don't update them to restate code
- API documentation belongs in the route file, not a separate wiki that can drift out of sync
