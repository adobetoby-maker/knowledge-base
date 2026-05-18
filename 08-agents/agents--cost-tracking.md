# Per-Task Agent Cost Tracking

## Why Track Per Task

Aggregate API billing tells you how much you spent in total. It doesn't tell you which task type is burning 80% of the budget, which agent is calling a large model when a small one would do, or when a runaway task has consumed $50 before anyone noticed.

Per-task tracking answers: what did this specific task cost, which task types are most expensive, and which tasks are over budget.

## Token Counting Per API Call

Every API response includes input and output token counts. Capture them immediately after each call:

```typescript
interface TokenUsage {
  task_id: string;
  step_name: string;
  model: string;
  input_tokens: number;
  output_tokens: number;
  cache_read_tokens: number;   // prompt cache hits (cheaper)
  cache_write_tokens: number;  // prompt cache writes (slightly more)
  cost_usd: number;
  timestamp: string;
}

function recordUsage(taskId: string, stepName: string, response: APIResponse): TokenUsage {
  const { model, usage } = response;
  const cost = calculateCost(model, usage);
  const record = { task_id: taskId, step_name: stepName, model, ...usage, cost_usd: cost, timestamp: new Date().toISOString() };
  db.token_usage.create({ data: record }); // fire and forget — don't await in critical path
  return record;
}
```

Don't estimate costs after the fact by re-tokenizing. Capture actual counts from the response where possible — tokenization is model-specific and estimates are often wrong.

## Cost Per Model (Per 1M Tokens)

Reference table for current Anthropic pricing (verify against https://anthropic.com/pricing — prices change):

| Model | Input | Output | Cache Read | Cache Write |
|---|---|---|---|---|
| claude-opus-4 | $15 | $75 | $1.50 | $18.75 |
| claude-sonnet-4-5 | $3 | $15 | $0.30 | $3.75 |
| claude-haiku-4-5 | $0.80 | $4 | $0.08 | $1.00 |

Cost formula:
```typescript
function calculateCost(model: string, usage: Usage): number {
  const rates = MODEL_RATES[model];
  return (
    (usage.input_tokens / 1_000_000) * rates.input +
    (usage.output_tokens / 1_000_000) * rates.output +
    (usage.cache_read_tokens / 1_000_000) * rates.cache_read +
    (usage.cache_write_tokens / 1_000_000) * rates.cache_write
  );
}
```

Store rates in a config file or DB table so they can be updated without a deploy when Anthropic changes pricing.

## Budget Enforcement

Set a budget per task at creation time. Enforce it before each API call:

```typescript
async function checkBudget(taskId: string): Promise<void> {
  const { budget_usd, spent_usd } = await db.task.findUnique({ where: { id: taskId } });
  const pct = spent_usd / budget_usd;

  if (pct >= 1.0) throw new BudgetExceededError(taskId, spent_usd, budget_usd);
  if (pct >= 0.8) await alertBudget(taskId, pct); // at 80%, warn but continue
}
```

Call `checkBudget` before every API call in the task. This ensures the task stops cleanly instead of silently blowing past the limit.

On budget exceeded: mark the task `budget_exceeded`, save progress checkpoint, notify the user with what was completed and what remains, offer the option to extend the budget and continue.

## Alerting at 80% Budget

The 80% alert is a human decision point: "Do I want this task to continue?" It shouldn't require immediate action, but it should be visible.

- In-app notification: "Task 'Market Analysis' has used 80% of its $5.00 budget ($4.02 spent)"
- Include: task name, budget, spent, estimated cost to complete if you have prior runs to compare
- Don't page/SMS at 80% — it's not an emergency, it's a heads-up

Log all budget events to a `budget_events` table: `task_id`, `event_type` (80_pct_alert | exceeded | extended), `spent_usd`, `budget_usd`, `timestamp`.

## Cost Attribution by Task Type

Tag every task with a `task_type` at creation. Aggregate cost reports group by this:

```sql
SELECT task_type,
       COUNT(*) as task_count,
       SUM(cost_usd) as total_cost,
       AVG(cost_usd) as avg_cost,
       MAX(cost_usd) as max_cost
FROM token_usage
JOIN tasks ON tasks.id = token_usage.task_id
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY task_type
ORDER BY total_cost DESC;
```

Run this report weekly. It surfaces which task types have unexpectedly high costs, which are candidates for model downgrade (same quality, cheaper model), and which are worth caching or batching.

## Key Rules

- Record input tokens, output tokens, and cache tokens from every API response — never estimate retroactively
- Store model pricing in configuration, not hardcoded — prices change quarterly
- Check budget before every API call; throw cleanly when exceeded, don't let the task overshoot
- Alert at 80% budget as a heads-up, not an emergency
- Tag every task with a `task_type` for cost attribution reporting
- Run monthly cost-by-task-type reports to identify over-expensive flows and model downgrade candidates
