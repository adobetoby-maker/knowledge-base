# Agent Execution Tracing

## Traces vs Logs

**Logs** are timestamped lines of text capturing what happened at a single point. They're great for "what error occurred?" but poor for "why did the agent take the wrong branch on step 4?"

**Traces** are structured records of an entire execution: every step, its inputs and outputs, duration, and how steps relate to each other. A trace answers "what was the agent thinking and what did it do, in order."

For agents, traces are primary. Logs are secondary. You cannot debug a multi-step agent from logs alone.

## Structured Trace Schema

Every agent step produces a trace record:

```typescript
interface AgentTraceStep {
  trace_id: string;       // shared across entire task execution
  task_id: string;
  step_id: string;        // unique per step (UUID)
  parent_step_id?: string; // for nested / sub-agent steps
  step_name: string;      // human-readable: "search_customer", "validate_refund_eligibility"
  step_type: "thought" | "tool_call" | "tool_result" | "decision" | "output";
  input: unknown;         // what the step received
  output: unknown;        // what the step produced
  duration_ms: number;
  model?: string;         // if this was an LLM call
  token_usage?: TokenUsage;
  error?: string;
  timestamp: string;
}
```

Storing `input` and `output` is what makes replay possible. Without them, you have timing data but can't reconstruct what happened.

## Trace ID Propagation

Every execution starts with a single trace ID, generated at task creation. This ID must flow through:

- Every API call (as a header: `X-Trace-ID`)
- Every database write (as a column)
- Every log line (as a structured field: `{ trace_id, message, level }`)
- Every sub-agent spawned from this task

```typescript
// Pass trace_id in context, not global state
async function runStep(ctx: AgentContext, stepName: string, fn: () => Promise<unknown>) {
  const start = Date.now();
  const stepId = generateId();
  try {
    const output = await fn();
    await writeTrace({ trace_id: ctx.traceId, step_id: stepId, step_name: stepName, output, duration_ms: Date.now() - start });
    return output;
  } catch (err) {
    await writeTrace({ trace_id: ctx.traceId, step_id: stepId, step_name: stepName, error: err.message, duration_ms: Date.now() - start });
    throw err;
  }
}
```

When a sub-agent is spawned, pass the parent's `trace_id` as the `parent_trace_id`. This lets you reconstruct the full tree of execution across agents.

## Log Aggregation

Structured logs (JSON, not plaintext) allow aggregation. Each log line includes `trace_id`:

```json
{ "ts": "2026-05-18T14:23:01Z", "level": "info", "trace_id": "trc_abc", "task_id": "task_123", "msg": "Starting refund eligibility check", "order_id": "ord_88" }
```

In a log aggregation system (Datadog, Loki, CloudWatch Logs Insights), query all logs for a trace: `trace_id = "trc_abc"`. You get every log line from every service involved in that execution, in order.

The trace table gives you step-level structure. The logs give you fine-grained detail within steps. Use both.

## Replay Capability

With inputs stored per step, you can replay any step in isolation:

```typescript
async function replayStep(traceId: string, stepName: string): Promise<unknown> {
  const step = await db.trace.findFirst({ where: { trace_id: traceId, step_name: stepName } });
  // Re-run the step with the same input that was captured during the original run
  return runToolCall(step.step_name, step.input);
}
```

Replay is invaluable for debugging: take a failed production trace, replay the step that went wrong with its original input, add breakpoints, iterate. No need to reconstruct the environment from scratch.

Don't store inputs that contain credentials or PII without masking. Mask before writing to trace storage: replace credit card numbers, tokens, and passwords with `[REDACTED]`.

## Querying Traces for Debugging

Common debugging queries:

```sql
-- All steps for a specific task execution
SELECT step_name, step_type, duration_ms, error
FROM agent_traces WHERE trace_id = 'trc_abc' ORDER BY timestamp;

-- Steps that exceeded 5 seconds (latency outliers)
SELECT step_name, AVG(duration_ms), MAX(duration_ms)
FROM agent_traces WHERE duration_ms > 5000 GROUP BY step_name;

-- Error rate by step name (last 7 days)
SELECT step_name, COUNT(*) FILTER (WHERE error IS NOT NULL) / COUNT(*)::float as error_rate
FROM agent_traces WHERE timestamp > NOW() - INTERVAL '7 days' GROUP BY step_name ORDER BY error_rate DESC;
```

## Key Rules

- Traces are structured records of execution; logs are text notes within steps — both are required
- Every step records: step name, type, input, output, duration, and error if applicable
- Generate one trace ID per task at creation; propagate it through every API call, DB write, and sub-agent
- Mask PII and credentials before writing inputs/outputs to trace storage
- Store inputs verbatim to enable step replay during debugging
- Correlate traces and logs via trace_id in your aggregation system
