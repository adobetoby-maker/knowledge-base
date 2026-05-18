# Agent: Coordinator Agent

A coordinator agent delegates work to specialist agents and aggregates their outputs into a coherent result. It does not do the specialist work itself — its job is routing, sequencing, progress tracking, and synthesizing. The coordinator is useful when a task requires capabilities that are better handled by purpose-built agents than by a single generalist.

## Capability Registry

The coordinator needs a registry that maps task types to agent capabilities. This can be as simple as a static configuration or as dynamic as agent self-description:

```ts
const CAPABILITY_REGISTRY = {
  'web-search': {
    agent: 'search-agent',
    inputs: ['query', 'max_results'],
    outputs: ['results[]'],
    timeout_ms: 15000,
  },
  'code-review': {
    agent: 'code-agent',
    inputs: ['code', 'language', 'focus'],
    outputs: ['issues[]', 'suggestions[]'],
    timeout_ms: 30000,
  },
  'fact-check': {
    agent: 'fact-check-agent',
    inputs: ['claims[]'],
    outputs: ['verdicts[]'],
    timeout_ms: 45000,
  },
};
```

The registry prevents the coordinator from routing tasks to agents that don't support them, and provides timeout and schema contracts that the coordinator enforces.

## Task Routing

When a task arrives, the coordinator decomposes it into sub-tasks and matches each sub-task to a capable agent. The routing decision should be based on the sub-task's required capabilities, not on surface-level text matching.

Routing logic:
1. Identify what the sub-task needs to produce (output type).
2. Look up which agents produce that output type.
3. If multiple agents can handle it, prefer the most specialized (less likely to fail outside its domain).
4. If no agent can handle it, either flag it as unroutable or handle it directly (only for simple sub-tasks).

Sequence vs. parallel: sub-tasks with dependencies must be sequenced (search first, then synthesize from results). Sub-tasks that are independent can run in parallel. The coordinator builds this execution plan before spawning any agents.

## Progress Aggregation

Track the state of each delegated sub-task:

```ts
type SubTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'timeout';

interface SubTask {
  id: string;
  capability: string;
  agent: string;
  status: SubTaskStatus;
  startedAt?: Date;
  completedAt?: Date;
  result?: unknown;
  error?: string;
  retries: number;
}
```

The coordinator checks this state table when deciding next steps. Completed sub-tasks feed their outputs into dependent sub-tasks. Failed sub-tasks trigger the error handling logic.

Emit progress events upward (to the caller or UI) so long-running coordination tasks have observable progress rather than appearing stuck.

## Handling Specialist Agent Failure

When a specialist agent fails (error, timeout, or invalid output), the coordinator has four options:

1. **Retry**: Re-submit with the same input, up to a configured max (typically 2). Useful for transient failures (network, rate limits).
2. **Fallback to different agent**: If another agent in the registry has the same capability, route to it. Useful for redundant capability coverage.
3. **Degrade gracefully**: Complete the task without that sub-task's output. Useful when the sub-task is enrichment, not critical path.
4. **Fail the whole task**: If the sub-task is on the critical path and has no fallback, propagate the failure upstream with a clear error message describing which agent failed and why.

Never silently absorb a sub-task failure and return a result that omits data without noting the gap. If a fact-check agent timed out and the coordinator returns unverified content as if it were verified, that is worse than failing explicitly.

## Synthesis

After all sub-tasks complete, the coordinator synthesizes their outputs into the final result. Synthesis is not concatenation — it involves:
- Deduplication (multiple search agents may return overlapping results)
- Conflict resolution (two agents may produce contradictory assessments)
- Structuring (organizing outputs according to the original task's schema)
- Summarization if individual outputs are verbose

The synthesis prompt should include all sub-task outputs and the original task requirements. The coordinator should note in the final output which parts came from which agents, especially when confidence varies across sources.

## Key Rules

- The coordinator routes and synthesizes; it does not execute specialist work itself.
- Build the execution plan (sequence + parallel structure) before spawning any sub-tasks.
- Always track sub-task status — a coordinator that can't report what its agents are doing is a black box.
- Fail explicitly rather than returning degraded results without noting the degradation.
- Set timeouts per capability in the registry and enforce them — an unresponsive agent should not block the coordinator indefinitely.
- Emit progress events for tasks expected to take more than a few seconds.
