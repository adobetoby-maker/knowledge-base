# Agents: Error Escalation Ladder

## Overview
Agents encounter failures constantly: network timeouts, invalid tool responses, context limits, ambiguous instructions, unexpected data formats. The failure mode matters: swallowing errors silently produces agents that report success while delivering garbage. Escalating every minor error to a human produces agents that can't function without constant supervision. The escalation ladder defines the response to each class of failure before the agent runs — not reactively during execution.

## The Escalation Ladder

Define the response levels in order. Apply the lowest level that might succeed before escalating:

**Level 1: Retry**
- Condition: transient failure (network timeout, rate limit, temporary API error)
- Action: wait and retry (exponential backoff for rate limits)
- Max retries: 3 with increasing delay
- Proceed to Level 2 if all retries fail

**Level 2: Fallback**
- Condition: primary approach failed, alternative exists
- Action: use alternative tool, API, or strategy
- Examples: primary search fails → use cached results; preferred API down → use backup API
- Proceed to Level 3 if fallback also fails or no fallback exists

**Level 3: Degrade**
- Condition: partial completion is possible; full completion is not
- Action: return what was successfully completed; clearly mark the result as partial
- Include: what was completed, what was not, why
- Never mark a partial result as complete — this is the most dangerous failure mode
- Proceed to Level 4 if even partial completion is not meaningful

**Level 4: Escalate to Human**
- Condition: cannot proceed without human decision or the task is too important to deliver partially
- Action: surface the problem with enough context for the human to act: what failed, what was tried, what decision is needed
- Do not continue executing after escalating — wait for human input
- Proceed to Level 5 if human is unavailable and task cannot wait

**Level 5: Abort**
- Condition: unrecoverable error, safety constraint violation, or task integrity cannot be guaranteed
- Action: stop entirely; log everything; return structured error to caller
- Never partially execute a destructive action that cannot be rolled back

## Pre-Task Definition

Define the escalation ladder for each agent task type before the agent runs:
- What constitutes a transient vs permanent error?
- What fallbacks exist for each tool?
- Can this task be meaningfully delivered as partial?
- Who is the human escalation target (a queue? a specific person? an alert?)
- What constitutes an abort condition?

## Error Logging at Each Level

Every time the ladder advances, log:
- The error that triggered escalation
- The level being attempted
- What was tried at the previous level and why it failed
- The current state of the task (what completed, what didn't)

This log is the debugging record if the task ultimately fails.

## Silent Success = Worst Failure Mode

An agent that catches all errors, returns "success," but delivers an empty or incorrect result is worse than one that aborts loudly. Silent success:
- Reaches downstream systems before anyone notices
- Is harder to debug (no error signal to trace)
- May trigger automated follow-up actions on bad data

Rule: if the result cannot be guaranteed correct, mark it as partial or return an error. Never fabricate success.

## Key Rules

- Define the escalation ladder before deployment — reactive error handling design is always worse
- Retry only for transient errors — retrying a logic error wastes time and cost
- Partial results must be explicitly marked as partial — never report partial as complete
- Log at every escalation step — the log is the debugging record
- Silent success with bad data is the worst failure mode — prefer loud failures
- Abort conditions must be defined upfront for any task with irreversible effects
