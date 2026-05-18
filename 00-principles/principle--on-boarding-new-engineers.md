# Principle: Onboarding New Engineers

## Overview
The first 90 days determine whether an engineer becomes a net contributor or a drain on the team. The most common failure is throwing a new engineer at large, ambiguous work before they have context — they block on every unknown, feel ineffective, and the team loses patience. A structured ramp gives small wins that build confidence while accumulating the context needed for larger contributions.

## Implementation / Key Points

### Day 1: Run the App Locally (Setup Win)
The first milestone is a locally running app with a working test suite. If setup takes more than 2 hours, the setup process is broken — fix it.

Onboarding setup script checklist:
```bash
# Should take < 30 minutes on a clean machine
git clone <repo>
cp .env.example .env.local  # pre-filled with dev values, not empty stubs
npm install
npm run db:setup             # creates local DB + runs migrations + seeds
npm run dev                  # starts without errors
npm run test                 # all pass
```

Anything that requires tribal knowledge (asking Slack, special certificates, access requests) is a blocker to document and fix.

### Week 1: Fix a Small Bug (Real Contribution)
Pick a bug that:
- Touches a real production code path (not just tests or docs)
- Is small enough to fix in 1–3 days
- Requires reading 3–5 files to understand the context

The goal is a shipped PR, not a polished feature. The code review process itself teaches more about team standards than any onboarding document.

### Month 1: Own a Feature (Full Cycle)
Assign a complete small feature: spec → implementation → tests → PR → deploy. This exposes the new engineer to the full workflow including:
- How requirements are defined
- How decisions are made during implementation
- What the review process looks like
- How deployment and monitoring work

### Assign a Buddy (Not the Manager)
The buddy's job:
- Available for "dumb questions" without social cost
- Not their manager (different power dynamic)
- Not the most senior engineer (too busy)
- Checks in daily for the first 2 weeks, weekly after that

### Document Gotchas as Discovered
When the new engineer hits something surprising, they add it to the onboarding docs — the friction is still fresh. This is the most effective way to keep onboarding docs accurate.

```markdown
## Gotchas

### The admin client bypasses RLS
`lib/supabase/admin.ts` uses the service role key and ignores all row-level security policies.
Never import it in client-side code. See ADR-007 for context.

### Port 3000 must be free
The dev server assumes port 3000. Kill anything on 3000 before `npm run dev`.
```

### Measuring Success
| Metric | Target |
|---|---|
| Time to first local run | < 2 hours |
| Time to first merged PR | < 5 business days |
| Time to first owned feature | < 30 days |
| 90-day retention | > 95% |

## Key Rules
- Day 1 ends with a locally running app — if not, the setup is broken.
- First task is a real bug fix, not documentation cleanup or test writing.
- Buddy is a peer, not the manager, and not the most senior person.
- New engineers document what surprised them — they have the freshest perspective on gaps.
- Measure time-to-first-PR; if it's > 5 days, the onboarding process needs work.
- Ambiguous first tasks ("explore the codebase") produce anxiety, not learning.
