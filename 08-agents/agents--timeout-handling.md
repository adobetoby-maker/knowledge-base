# Agent Timeout Handling

## Why This Matters

Agents that silently hang — or crash and return nothing — destroy user trust faster than slow agents. A task that times out with a partial result, a checkpoint to resume from, and a clear message about what was completed is far better than a full retry from scratch. Design for timeout as a first-class outcome, not an edge case.

## Per-Step vs Total Timeout

Set both:

**Per-step timeout** — the maximum time any single tool call, LLM call, or sub-task may take. This prevents one slow operation from consuming the entire budget. Typical: 10–30s for LLM calls, 5–15s for tool calls.

**Total timeout** — the maximum wall-clock time for the entire task. This is the contract with the caller. Typical: 60s for interactive tasks, 10–30min for background jobs.

Never rely on only one. A per-step timeout without a total timeout lets an agent with many steps exceed the wall-clock budget. A total timeout without per-step timeouts lets a single runaway step starve the rest.

```python
import asyncio

async def run_with_timeout(coro, step_limit=20, total_limit=120):
    try:
        return await asyncio.wait_for(
            asyncio.wait_for(coro, timeout=step_limit),
            timeout=total_limit
        )
    except asyncio.TimeoutError:
        raise StepTimeoutError("step exceeded limit")
```

## Partial Result Return

When a total timeout fires, return whatever has been completed — do not discard it. An agent that processed 7 of 10 documents should return the 7. The calling layer can decide whether to surface partial results or retry.

Structure results to make partial completion detectable:

```json
{
  "status": "partial",
  "completed": 7,
  "total": 10,
  "results": [...],
  "checkpoint": "doc_id_8",
  "message": "Timed out after 120s. Resume from checkpoint."
}
```

## Resumable Checkpoints

For long-running agents, write a checkpoint after each meaningful unit of work — not just at the end. The checkpoint must contain enough state to restart without redoing completed work:

- Current position (index, cursor, ID of last processed item)
- Accumulated partial output
- Any derived state that would be expensive to recompute

Store checkpoints to a fast durable store (Redis with a TTL, or a Supabase row). Do not store checkpoints in memory — a timeout event may kill the process.

When resuming, load the checkpoint and pass it as initial state. The agent should behave identically whether starting fresh or resuming mid-task.

## Informing the User

Never surface a raw timeout error to a user. Always translate:

- What was completed: "Analyzed 7 of 10 documents"
- What remains: "3 documents were not processed"
- What to do: "You can retry the remaining items or view partial results now"

For background tasks, write a status row the UI can poll. For synchronous tasks, return a structured partial response with `status: "partial"`.

Avoid phrases like "an error occurred" or "request timed out" — these tell the user nothing actionable.

## Key Rules

- Set both per-step and total timeouts — never just one
- Return partial results on timeout; never discard completed work
- Write checkpoints to durable storage after each meaningful unit
- Expose `status`, `completed`, `checkpoint`, and `message` in all partial responses
- Translate timeout errors into user-actionable language before surfacing them
- For streaming agents, flush partial output before the timeout kills the connection
