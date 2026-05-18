# Agents: Progressive Context Building

## Overview
A common agent design mistake is front-loading the context window with everything that might be needed: full file contents, all documentation, complete conversation history. This wastes tokens (cost), dilutes attention (accuracy), and often hits context limits before the task is complete. Progressive context building — starting lean and adding only what the next step requires — produces better results at lower cost.

## The Principle

Treat context as working memory: load what you need for the current step, not everything that might eventually be needed. This mirrors how experienced developers work — they don't read the entire codebase before writing a function; they read the relevant module, the function signature, and the types involved.

## Pattern: Outline → Identify → Load → Execute

**Step 1 — Outline the task**
Before touching any files or APIs, produce a plan:
- What is the goal?
- What sub-steps are required?
- What information is needed for each step?

This costs almost nothing and prevents loading irrelevant context.

**Step 2 — Identify what's needed for step 1**
From the plan, determine the minimal information needed to execute the first sub-step. For code tasks: which files? Which functions? For research tasks: which sources? Which specific facts?

**Step 3 — Load that specific context**
Read only those files, call only those APIs, retrieve only those search results. Don't speculatively load adjacent files "just in case."

**Step 4 — Execute step 1, then repeat**
After completing step 1, reassess: what does step 2 actually require now that step 1 is done? The answer often differs from the initial plan. Load the new context, execute, repeat.

## Anti-Patterns to Avoid

**Loading entire codebases**
Reading all files in a repo to answer a question about one module wastes context and buries the relevant signal in noise. Use search to locate the specific file/function, then read that.

**Speculative context loading**
"I might need this later" → don't load it. Load on demand, when the step actually requires it.

**Retaining stale context**
Context loaded for step 1 that is no longer relevant for step 5 should be dropped (or summarized) rather than retained verbatim. Stale context increases cost and can confuse the model.

**Tool call waterfall**
Making 10 search calls upfront to "have everything available" instead of making search calls precisely when each answer is needed. Sequential tool calls with progressive narrowing are more accurate.

## Context Budget Allocation

Think about context window space as a budget:
- System prompt: ~10–20% (fixed)
- Task state and completed work: ~10–20% (grows during execution)
- Active working context (current file, current search results): ~30–40%
- Response headroom: ~20–30%

If active working context grows to 60% of the window, it's a sign of over-loading.

## When to Pre-Load

Some contexts are worth loading upfront:
- Short, high-density reference material that will be needed throughout (a schema definition, a style guide)
- Configuration that affects all steps (env vars, tool capabilities)
- User requirements that must be checked at every step

The test: "will I reference this in 3+ steps?" → load upfront. "Will I reference this in 1 step?" → load on demand.

## Key Rules

- Plan before loading any context — the plan reveals what's actually needed
- Load context one step at a time, not all upfront
- Use search/grep to locate the relevant piece before loading the whole document
- Drop or summarize stale context actively — don't just accumulate
- Budget the context window: track token usage and adjust loading strategy when over 70%
- "Just in case" loading is always wrong — it increases cost and rarely improves accuracy
