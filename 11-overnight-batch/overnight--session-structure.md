# Overnight Batch Session Structure

**When:** Starting an autonomous session without a human available.
**Rule:** Every overnight session follows a strict structure. Deviation causes unrecoverable states.

## Session Template

```
PHASE 1 — LOAD CONTEXT (2 minutes)
  1. mcp__plugin_claude-mem_mcp-search__memory_context({})
  2. mcp__plugin_claude-mem_mcp-search__search({ query: "[task topic]", limit: 5 })
  3. Read relevant project file from 07-projects/
  4. Load task bundle from 13-stack-bundles/ if available
  → If context load fails: log to session.log, proceed with CLAUDE.md only

PHASE 2 — ASSESS CURRENT STATE (5 minutes)
  1. Read the target files — understand current state before changing anything
  2. Check git status: are there uncommitted changes?
  3. Check if dev server or build is in a broken state
  4. Identify blockers that require human input
  → If blockers found: log to NEEDS_HUMAN.md, skip affected steps, continue others

PHASE 3 — DO THE WORK
  1. Take the simplest path that achieves the goal
  2. After each logical unit: git commit with descriptive message
  3. After each file change: verify the change makes sense before moving on
  4. If blocked on step N: log it, skip to step N+1

PHASE 4 — VALIDATE (before finishing)
  1. Run build: npm run build
  2. Run type check: npx tsc --noEmit
  3. Run lint if available
  4. If any fail: fix before marking done, or log as NEEDS_HUMAN if unfixable

PHASE 5 — CLOSE OUT
  1. git commit all changes with clear message
  2. mcp__plugin_claude-mem_mcp-search__observation_add({ content: "Session summary" })
  3. Update NEEDS_HUMAN.md if anything requires human attention
  4. Do NOT push to main — push to a branch
```

## The NEEDS_HUMAN.md Pattern
Create this file at the project root if any step was skipped:
```markdown
# Needs Human Attention

## [timestamp]
**Blocked on:** [description of what couldn't be done]
**Why:** [reason — missing credential, unclear requirement, etc.]
**To continue:** [what the human needs to do to unblock]
**Files affected:** [list]
```

## Decision Rules for Autonomous Work
- IF two approaches are equally valid → choose the simpler one
- IF an approach is irreversible (delete, drop, rm) → SKIP and log to NEEDS_HUMAN.md
- IF a credential is missing → SKIP that step, continue others
- IF a build is already broken → fix it first before adding new code
- IF tests are failing → either fix them or log to NEEDS_HUMAN.md before adding more code
- NEVER push to main
- NEVER delete files
- NEVER apply DB migrations without explicit instruction

## Commit Message Format for Overnight Sessions
```
[AUTO] Brief description of what was done

- Specific change 1
- Specific change 2
- Skipped: [anything that was skipped and why]
```
