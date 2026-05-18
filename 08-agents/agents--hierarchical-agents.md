# Hierarchical Multi-Agent Systems

A hierarchical system has manager agents that decompose goals and delegate to worker agents that execute. The value is isolation: each layer handles what it's good at, and failures at the worker level can be caught, retried, or rerouted without corrupting the higher-level goal.

## Manager-Worker Structure

The manager's job is decomposition and coordination, not execution. It should:
- Parse the high-level goal into subtasks with clear input/output contracts.
- Route each subtask to the appropriate specialized worker.
- Collect and validate worker outputs.
- Synthesize results into the final deliverable.

The worker's job is execution within its domain. Workers should be narrow and deep — a code-writer worker, a search worker, a data-transform worker. A worker that tries to do everything is a flat agent with a misleading label.

The manager should not know how a worker does its job; it only knows what input to send and what output to expect. This is the same contract as an API — implementation details are hidden.

## Delegating Based on Specialization

Specialization pays off because narrow workers can have domain-specific tools, prompts tuned for their task type, and tight output schemas. A search worker has web search tools; a code worker has an interpreter; a summarization worker has access to the full document and a summarization-optimized prompt.

The manager routes based on subtask type, not worker availability. If the manager knows "this step requires code execution," it always routes to the code worker — not whichever worker responded last. Hard-code the routing logic; dynamic routing introduces ambiguity about which worker is authoritative.

## Result Aggregation

After workers return, the manager aggregates. Aggregation pitfalls:
- **Contradiction**: two workers return conflicting facts. The manager must have a resolution rule — trust the source-cited answer, or flag for human review, or re-query with both outputs as context.
- **Missing output**: a worker fails silently and returns an empty or error result. The manager needs a null-check before aggregating.
- **Format mismatch**: workers using different schemas for the same data type. Define a canonical schema at the manager layer and validate worker output against it before aggregation.

## Failure Isolation

One worker failing should not cascade to the manager or other workers. Implement at the manager layer:
- Wrap each worker call in try/catch with a typed error result.
- Distinguish retryable failures (timeout, rate limit) from terminal failures (invalid input, auth error).
- Retry transient failures with backoff; escalate terminal failures by substituting a fallback result or marking that subtask incomplete.
- Deliver partial results to the user if some workers succeeded and some failed — don't withhold all results because one subtask errored.

Never let a worker throw an unhandled exception that propagates up and kills the manager process. The manager layer is the exception boundary.

## Key Rules

- Manager decomposes and routes; workers execute. Never mix these roles in one agent.
- Workers must be narrow and deep — broad workers are flat agents in disguise.
- Manager-worker interface is a contract: defined input schema, defined output schema. No free-form passing.
- Failure isolation is the manager's responsibility, not the worker's.
- Contradicting worker results require a defined resolution rule before shipping; "just pick one" is not a rule.
- Partial success is a valid deliverable — surface completed subtasks even when some fail.
