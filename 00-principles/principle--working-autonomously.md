# Working Autonomously — Principles for Unsupervised AI Sessions

## The Two-Speed Workspace

Human-supervised sessions and autonomous sessions require different operating modes.

**Supervised (human present):** Ask when uncertain. Surface options. Explain tradeoffs. The human is the decision-maker and can respond immediately to ambiguity.

**Autonomous (overnight/unattended):** Resolve ambiguity through documented research. Default to safer options. Log blocked decisions for human review. Never stop the entire session because one task is uncertain.

## Act on Reversible, Log Irreversible

**Self-authorize:**
- Creating and editing files
- Pushing non-main branches
- Running builds, tests, lints
- Deploying to preview environments
- Installing packages
- Starting or restarting development servers

**Log and continue (don't execute):**
- Database schema changes (without prior approval)
- Production deploys of auth-affecting changes
- Any deletion operation
- Force push to main
- Removing or downgrading dependencies (unless build requires it)

When a task requires a logged action, append to NEEDS_HUMAN.md and continue with remaining tasks.

## Decision Under Ambiguity

When a task is ambiguous and the human is unavailable:

1. Search for precedent: is there an existing implementation in the codebase that resolves the ambiguity?
2. Check corrections-log.md: is there a documented rule?
3. Choose the safer interpretation: the one with lower blast radius if wrong
4. Log the interpretation taken: write a comment or NEEDS_HUMAN.md entry noting which interpretation was chosen

Never make a high-blast-radius decision by guessing.

## NEEDS_HUMAN.md Protocol

Every project root should have (or can be created with) a NEEDS_HUMAN.md file.

Format:
```markdown
## [Task Name] — [date time]
BLOCKER: [what the agent cannot proceed without]
ATTEMPTED: [what was tried]
OPTIONS:
  A) [safe option and its consequence]
  B) [bolder option and its consequence]
NEXT STEP: Review this entry and run: [specific command or action]
```

After appending to NEEDS_HUMAN.md, the session continues with all remaining non-blocked tasks.

## Progress Tracking

For long autonomous sessions, maintain a progress log:

```
STARTED: [task list count] tasks at [time]
COMPLETED: task name → path/of/changed/file
FAILED: task name → reason → see NEEDS_HUMAN.md
SKIPPED: task name → reason (blocked by COMPLETED task failure)
SUMMARY: X completed, Y failed, Z skipped — ready for human review
```

This log gives the human a clear picture of what happened without needing to read all changed files.

## The Stop Condition

An autonomous session should NOT stop unless:
1. A critical prerequisite for ALL remaining tasks is unavailable (e.g., cannot access any file in the project)
2. A canary watch failure indicates production is broken
3. The NEEDS_HUMAN list is so long that the human must be consulted before more work proceeds (>3 blocking items)

In all other cases: continue. A session that stops because one of fifteen tasks had ambiguity wasted the time investment in setting it up.

## Session Summary on Completion

End every autonomous session with a structured summary to NEEDS_HUMAN.md or a separate SESSION_SUMMARY.md:

```markdown
## Session Complete — [date]

### Completed
- [list of completed tasks with file paths]

### Needs Review
- [list of NEEDS_HUMAN entries]

### Canary Status
- [pass/fail status of any deployed changes]

### Suggested Next Steps
1. [Highest priority review item]
2. [Second priority]
```
