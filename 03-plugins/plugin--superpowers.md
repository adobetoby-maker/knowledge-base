# Plugin: superpowers@claude-plugins-official

**What it provides:** Meta-skills that improve HOW you work: planning, debugging, code review, writing, agent orchestration.
**When to reach for it:** These are process skills — invoke them before task skills. They determine approach, not implementation.

## Key Skills (Process-First)

### Planning
- `superpowers:writing-plans` — how to write a good implementation plan before coding
- `superpowers:executing-plans` — how to follow a plan without drifting
- `superpowers:brainstorming` — structured brainstorming for complex problems

### Debugging
- `superpowers:systematic-debugging` — methodical approach: reproduce → isolate → hypothesize → fix → verify

### Development
- `superpowers:test-driven-development` — TDD cycle: red → green → refactor
- `superpowers:subagent-driven-development` — use agents for parallel work effectively
- `superpowers:dispatching-parallel-agents` — orchestrate multiple agents simultaneously
- `superpowers:using-git-worktrees` — parallel development in isolated worktrees

### Review
- `superpowers:requesting-code-review` — how to frame a code review request for best results
- `superpowers:receiving-code-review` — how to process and apply review feedback

### Finishing
- `superpowers:finishing-a-development-branch` — checklist for closing out a feature branch
- `superpowers:verification-before-completion` — verify work is actually done before declaring done

## When to Invoke

**Before planning anything complex:** `superpowers:brainstorming` or `superpowers:writing-plans`
**When stuck on a bug after 3 attempts:** `superpowers:systematic-debugging`
**Before spawning parallel agents:** `superpowers:dispatching-parallel-agents`
**Before marking a feature done:** `superpowers:verification-before-completion` or `superpowers:finishing-a-development-branch`

## The Most Important One: systematic-debugging
When you're going in circles on a bug:
```
Skill("superpowers:systematic-debugging")
```
It enforces: write down what you know, form a specific hypothesis, test exactly that, don't guess.

## Priority Rule
Superpowers skills define HOW to approach a task.
Other skills define WHAT to do.
Always invoke superpowers FIRST when the task has significant complexity.

"I need to build X" → `superpowers:brainstorming` → then implementation skills.
"This bug is hard" → `superpowers:systematic-debugging` → then targeted fixes.
