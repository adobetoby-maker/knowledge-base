# Principle: Technical Writing in Codebases

## Overview
Code tells you what happens; writing tells you why. The "why" is what future engineers need when they encounter something surprising and must decide whether to change it. ADRs, RFCs, post-mortems, and changelogs are not documentation overhead — they are the primary way technical decisions survive team turnover. Ambiguous writing almost always reflects ambiguous thinking about the problem itself.

## Implementation / Key Points

### Architecture Decision Records (ADRs)
ADRs explain decisions after the fact — what was decided, why, and what alternatives were rejected.

```markdown
# ADR 012: Use cursor-based pagination instead of offset

## Status: Accepted (2024-03-15)

## Context
Our events table grows by ~100K rows per day. Offset pagination
becomes increasingly slow as offset grows (full table scan to page N).

## Decision
All paginated APIs will use cursor-based pagination (opaque next_cursor token).

## Alternatives Rejected
- **Offset pagination**: O(n) performance at high page numbers; inconsistent
  results when rows are inserted during pagination.
- **Keyset with timestamp only**: Ties on the same timestamp break ordering.

## Consequences
- API clients cannot jump to page N directly.
- Cursor tokens must be treated as opaque (not parsed by clients).
```

Store ADRs in `docs/decisions/` in the repo, numbered sequentially. They are append-only — amend by creating a new ADR that supersedes the old one.

### RFCs (Request for Comments)
Write an RFC before building anything that touches multiple services, changes a public API, or requires significant rework. The RFC forces you to articulate the problem and solution before you have code to hide behind.

```markdown
# RFC: Unified notification delivery system

## Problem
Three separate notification paths (email, SMS, push) have diverged in
reliability guarantees, retry logic, and observability.

## Proposed Solution
Single NotificationService with pluggable delivery adapters...

## Open Questions
- Should delivery failures be synchronous (block caller) or async (fire-and-forget)?
- Who owns the retry queue?

## Feedback requested by: 2024-04-01
```

An RFC that receives no pushback is still valuable — it creates a written record of the decision.

### Post-Mortems
Format: what happened, timeline, root cause, contributing factors, action items.

```markdown
## Incident: Payment failures, 2024-03-20 14:22–15:47 UTC

**Impact**: 340 failed payment attempts (~$28K blocked revenue)

**Root Cause**: Stripe webhook secret rotated without updating env var in prod.

**Contributing Factors**:
- No alert on webhook signature validation failure rate
- Secret rotation SOP did not include downstream services checklist

**Action Items**:
- [ ] Add PagerDuty alert for webhook validation failure > 1% (owner: @alice, by 2024-03-27)
- [ ] Add Stripe webhook secret to secrets rotation checklist (owner: @bob, by 2024-03-22)
```

### CHANGELOG (for External Consumers)
```markdown
## [2.4.0] - 2024-03-18
### Added
- Cursor-based pagination on /api/events

### Changed
- Rate limit headers now use standard `RateLimit-*` format (RFC 6585)

### Deprecated
- `page` and `per_page` query params; use `cursor` and `limit` instead

### Breaking (in 3.0.0)
- `page` param will be removed
```

## Key Rules
- ADRs explain WHY, not WHAT — code already shows what.
- Alternatives rejected section is mandatory — it prevents re-litigating decisions.
- Write the RFC before building, not after — the point is to get feedback while the design is still flexible.
- Post-mortem action items must have an owner and a due date — unassigned actions are never done.
- CHANGELOG is for API consumers, not engineers — write what they need to know to upgrade.
- Ambiguous writing is a signal to think harder about the problem, not to write more words.
