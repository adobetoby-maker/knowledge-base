# Spike Methodology for AI Agents

## What a Spike Is

A spike is a time-boxed, throwaway exploration task whose only output is a decision — not production code. The term comes from XP (Extreme Programming), where a spike answers "can we do this and how?" before committing sprint capacity.

For AI agents, spikes are essential because models have a strong bias toward completing what they start. An agent given a build task will build something, even if the right answer is "this approach won't work." A spike gives the agent explicit permission to explore and report without producing code.

## When to Spike

Spike before implementing when:
- The approach is unclear (two reasonable paths exist, each with different tradeoffs)
- The integration target is poorly understood (new API, unfamiliar library version)
- The task requires changing a system with unknown coupling (modifying auth, changing shared state)
- Previous attempts at similar work failed (check corrections-log.md and session-trajectory.md)
- The blast radius is high and the approach is uncertain

Skip spiking when:
- The approach is well-understood and has succeeded before
- The task is purely mechanical (rename, copy, format)
- The task has clear precedent in the codebase already

## Spike Prompt Structure

```
SPIKE TASK: [question to answer, not code to write]
CONTEXT: [what you know so far]
TIME BOX: [30 minutes / 1 session / this conversation]
OUTPUT FORMAT:
  - APPROACH: one paragraph describing the viable approach
  - RISKS: bullet list of what could go wrong
  - UNKNOWNS: questions that cannot be answered without trying
  - DECISION: PROCEED with [approach] or DO NOT PROCEED because [reason]
  - THROWAWAY CODE: [only if needed to validate feasibility — explicitly labeled]

Do NOT write production code during this spike.
```

## Two Types of Spikes

### Technical spike
Tests feasibility of a specific implementation approach.

Example: "Does Cloudflare Workers D1 support ACID transactions for our invoice generation use case? Spike to determine."

Output: A clear yes/no with the specific constraints that affect the design.

### Architectural spike  
Explores which of two+ designs is better for a given context.

Example: "Should we store session state in KV or in D1 for this Workers application? Spike to compare."

Output: A decision with explicit reasoning and the factors that would change the decision.

## Spike vs Implementation Boundary

The hardest part of spike discipline is preventing the spike from becoming an implementation. AI agents will naturally continue building once they have working code. Enforce the boundary explicitly:

In the spike prompt: "If you write any code, label it THROWAWAY at the top of every function."

At spike conclusion: "Delete any throwaway code before reporting results."

The spike output is a decision document, not a code artifact.

## Using Spike Results

After a spike, write its decision into the appropriate knowledge-base file for future sessions:

```
<!-- spike result 2026-05-17 -->
DECISION: D1 does NOT support multi-table ACID transactions in Cloudflare Workers.
Use KV for session + D1 for persistent records. Transactions must be modeled as
compensation patterns, not rollback.
```

This prevents future sessions from spiking the same question again.

## Spike Failure Is Success

A spike that concludes "DO NOT PROCEED — this approach will not work" is a successful spike. It prevented building the wrong thing. Log it in session-trajectory.md:

```
FAILED: Attempted D1 multi-table transactions → Spike revealed ACID not supported
LEARNED: D1 transactions are single-table only; compensation pattern required instead
```

This outcome is worth exactly as much as a successful implementation — it redirected effort away from a dead end before hours were invested.

## Spike for Overnight Batch Work

For local model overnight sessions, spike decisions must be pre-resolved. An overnight agent cannot interrupt to ask for a spike decision. Pre-run spikes during the day and encode the decisions as rules in the task prompt:

```
PRIOR RESEARCH: KV vs D1 spike resolved → use KV for session state (D1 not viable for ACID)
CONSTRAINT: All session writes must go to KV binding SESSION_KV
```

This converts spike knowledge into hard constraints that prevent the overnight agent from exploring the already-resolved question.
