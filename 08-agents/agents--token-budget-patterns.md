# Agents: Token Budget Management

## The Problem

Long agent runs consume large amounts of tokens in two ways: the growing conversation context (every message adds to the input), and the outputs themselves. Without budget management, a 1000-item batch job can cost 10x what it should because the context window fills with already-processed results.

## Context Window as a Depleting Resource

In a long-running agent session, the context fills up:
- Earlier messages stay in the window
- Each new response adds more context
- By item #200 of a 1000-item run, the model is reading 200 items of prior results on every call

**Fix**: Compress or replace context at checkpoints rather than letting it grow unbounded.

```ts
interface ContextBudget {
  maxTokensBeforeCompress: number   // trigger compression when context exceeds this
  compressionTargetTokens: number   // what to compress down to
  currentEstimate: number           // running estimate
}

// Checkpoint: replace accumulated results with a summary
async function maybeCompressContext(
  agent: Agent,
  budget: ContextBudget,
  results: ProcessedItem[]
): Promise<void> {
  if (budget.currentEstimate < budget.maxTokensBeforeCompress) return

  // Summarize what's been done
  const summary = await agent.summarize({
    prompt: `Summarize the following ${results.length} processed items in under 200 words:`,
    content: results,
  })

  // Replace context with summary + fresh instructions
  await agent.resetContext({
    retain: summary,
    instructions: 'Continue from the checkpoint above.',
  })

  budget.currentEstimate = budget.compressionTargetTokens
}
```

## Batch Size and Token Estimation

Estimate tokens before sending to control cost:

```ts
// Rough estimate: 1 token ≈ 4 characters (varies by content)
function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4)
}

function estimateBatchCost(items: string[], model: 'haiku' | 'sonnet' | 'opus') {
  const INPUT_COST = { haiku: 0.25, sonnet: 3.0, opus: 15.0 }   // per 1M tokens
  const OUTPUT_COST = { haiku: 1.25, sonnet: 15.0, opus: 75.0 }

  const inputTokens = items.reduce((sum, item) => sum + estimateTokens(item), 0)
  const estimatedOutputTokens = inputTokens * 0.3  // rough: output ~30% of input

  const costUsd = (
    (inputTokens / 1_000_000) * INPUT_COST[model] +
    (estimatedOutputTokens / 1_000_000) * OUTPUT_COST[model]
  )

  return { inputTokens, estimatedOutputTokens, costUsd }
}
```

Always estimate before starting a large batch. Present the cost to the user before running.

## Routing to Haiku for Token-Intensive Tasks

Any task that's "do X to each of 100 items" should use Haiku, not Sonnet:

```ts
// Routing rule: high-volume mechanical tasks → haiku
const model = items.length > 20 ? 'claude-haiku-4-5' : 'claude-sonnet-4-6'

// Never use Sonnet/Opus for:
// - String replacements across files
// - Format conversions
// - Simple data transformations
// - Image downloads, renames, moves
// - npm installs, git operations
```

## Prompt Caching for Repeated Context

When the same large context (codebase, documents, instructions) is needed for every item in a batch, cache it:

```ts
const messages = [
  {
    role: 'user',
    content: [
      {
        type: 'text',
        text: LARGE_STABLE_SYSTEM_CONTEXT,  // Same for every item
        cache_control: { type: 'ephemeral' },  // Cache this prefix
      },
      {
        type: 'text',
        text: `Process this specific item: ${item}`,  // Varies per item
      }
    ]
  }
]
```

Prompt caching reduces input token costs by ~90% for the cached portion when processing many items with the same context.

## Budget Guard

For overnight runs, add a hard spending limit:

```ts
const MAX_SPEND_USD = 5.00
let totalSpentUsd = 0

async function processWithBudget(item: string): Promise<void> {
  const estimate = estimateBatchCost([item], 'haiku')

  if (totalSpentUsd + estimate.costUsd > MAX_SPEND_USD) {
    throw new Error(`Budget exhausted ($${totalSpentUsd.toFixed(2)} / $${MAX_SPEND_USD}). Stopping.`)
  }

  const result = await processItem(item)
  totalSpentUsd += estimate.costUsd  // Track actual (use API response for accuracy)
}
```

Log actual token usage from API responses for accurate tracking — the estimate is just a pre-flight check.

## Batching vs Streaming

For 100+ items, process in batches of 10–20 rather than one at a time:
- Single-item: high API overhead per item
- Batch of 10: amortized overhead, still manageable context
- Batch of 100: context grows too large, errors harder to attribute

```ts
const BATCH_SIZE = 10
for (let i = 0; i < items.length; i += BATCH_SIZE) {
  const batch = items.slice(i, i + BATCH_SIZE)
  await Promise.all(batch.map(processItem))  // Parallel within batch
  await writeCheckpoint(i + batch.length)
}
```
