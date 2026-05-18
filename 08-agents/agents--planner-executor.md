# Planner-Executor Pattern

Separating planning from execution is the same cognitive move a human expert makes when outlining before writing, or architecting before coding. Mixing planning and execution produces reactive, short-horizon decisions that optimize locally but miss the global goal.

## Why Planning First Produces Better Results

When an agent executes immediately, each step is conditioned only on the previous step — it has no model of what the end state should look like. This produces correct-seeming intermediate steps that lead to the wrong destination.

Planning first forces the agent to reason about:
- What the final output needs to contain.
- What dependencies exist between steps (step 4 requires output from step 2).
- What resources or tools are needed before starting.
- What could go wrong and what the fallback is.

A plan is a hypothesis about how to reach the goal. Execution validates or refutes it. Without a plan, you're running an experiment without a hypothesis — you get results but can't interpret them.

## Plan Validation Before Execution

Before handing the plan to the executor, validate it:
- **Completeness**: does the plan cover all steps to get from current state to goal state?
- **Dependency ordering**: are steps in an order where prerequisites are satisfied before they're needed?
- **Resource availability**: does the plan call for tools or data that are actually available?
- **Scope**: is each step atomic enough for the executor to handle in one call, or does it need further decomposition?

Validation can be a lightweight LLM call with a checklist prompt, or rule-based (does each step have an assignee, input, and expected output?). Don't skip validation — a bad plan executed faithfully produces confidently wrong results.

## Dynamic Replanning When Execution Hits Obstacles

Execution will encounter surprises: a tool returns an unexpected format, a required resource is unavailable, an intermediate result invalidates a later step's assumptions. The executor must have a mechanism to surface these to the planner rather than improvising around them.

Pattern:
1. Executor hits a blocker — logs it as a structured `PlanObstacle` with: which step failed, what was expected, what was returned.
2. Planner receives the obstacle and the completed steps so far.
3. Planner produces a revised plan from the current state — it does not restart from scratch.
4. Revised plan is validated and execution resumes.

Cap replanning iterations. If the plan has been revised 3+ times, the goal itself may be underspecified. Surface to the user rather than continuing to replan in a loop.

## What the Executor Should Not Do

The executor is not empowered to change goals or skip steps. It executes the plan as given, reporting obstacles upward. This is the same constraint as a contractor following architect's drawings — they do not redesign the building when they hit a plumbing problem; they escalate.

Executors that silently work around plan failures produce outputs that are difficult to debug because the actual execution path diverged from the documented plan with no trace.

## Key Rules

- Never combine planning and execution in a single prompt pass for multi-step tasks.
- Plans must be validated for completeness, ordering, and resource availability before execution begins.
- Every execution obstacle surfaces to the planner as a structured report, not an improvised workaround.
- Replanning starts from the current completed state, not from scratch.
- Cap replan iterations (3 max) and escalate if exceeded — repeated replanning signals underspecified goals.
- Executors follow the plan; they do not interpret or extend it.
