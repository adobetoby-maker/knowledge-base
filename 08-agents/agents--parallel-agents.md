# Agent Pattern: Parallel Agents

## Overview

Run multiple independent subtasks concurrently with separate agent instances, then combine results. Reduces total wall-clock time from O(n) sequential to O(max) parallel. Critical for: multi-document analysis, batch processing, multi-source research.

## When Parallelism Applies

Only parallelize tasks that are truly independent:

```
Independent (can parallelize):
  - Analyze 5 different code files
  - Research 3 separate topics
  - Process 100 invoices
  - Run checks on N items from a list

NOT independent (must sequence):
  - Read file A, then analyze it based on what you found
  - Search for X, then based on results decide what to search next
  - Write a plan, then execute steps in the plan
```

## Parallel Dispatch Pattern

```ts
interface AgentTask {
  id: string
  instructions: string
  context?: string
}

interface AgentResult {
  id: string
  output: string
  error?: string
}

async function runParallel(
  tasks: AgentTask[],
  maxConcurrency = 5,
): Promise<AgentResult[]> {
  // Process in batches to control concurrency
  const results: AgentResult[] = []
  
  for (let i = 0; i < tasks.length; i += maxConcurrency) {
    const batch = tasks.slice(i, i + maxConcurrency)
    
    const batchResults = await Promise.allSettled(
      batch.map(async (task): Promise<AgentResult> => {
        const output = await runAgent(task.instructions, task.context)
        return { id: task.id, output }
      }),
    )
    
    for (const [index, result] of batchResults.entries()) {
      if (result.status === 'fulfilled') {
        results.push(result.value)
      } else {
        results.push({
          id: batch[index].id,
          output: '',
          error: result.reason?.message ?? 'Unknown error',
        })
      }
    }
  }
  
  return results
}
```

`Promise.allSettled` (not `Promise.all`) — one failed agent shouldn't fail the whole batch.

## Document Analysis Example

```ts
async function analyzeDocuments(docs: Document[]) {
  const tasks = docs.map((doc): AgentTask => ({
    id: doc.id,
    instructions: `Analyze this document and extract:
1. Key findings (bullet points)
2. Risk factors identified
3. Recommended actions
Respond in JSON: { findings: string[], risks: string[], actions: string[] }`,
    context: doc.content,
  }))

  const results = await runParallel(tasks, 5)

  // Aggregate results
  const allFindings = results
    .filter(r => !r.error)
    .flatMap(r => JSON.parse(r.output).findings)

  // Run synthesis agent with all findings
  const synthesis = await runAgent(
    `You have ${allFindings.length} findings from ${docs.length} documents. 
Identify themes and produce a summary report.`,
    allFindings.join('\n'),
  )

  return synthesis
}
```

## Map-Reduce Pattern

Parallelize the "map" phase, sequence the "reduce" phase:

```ts
async function mapReduceResearch(
  queries: string[],
  synthesisPrompt: string,
): Promise<string> {
  // MAP: parallel research
  const researchResults = await Promise.allSettled(
    queries.map(async (query) => {
      return await searchAndSummarize(query)
    }),
  )

  const summaries = researchResults
    .filter((r): r is PromiseFulfilledResult<string> => r.status === 'fulfilled')
    .map(r => r.value)

  // REDUCE: single synthesis agent
  return await runAgent(synthesisPrompt, summaries.join('\n\n---\n\n'))
}
```

## Rate Limit Awareness

Parallel agents hit rate limits faster. Build in rate limit handling:

```ts
class RateLimitedAgentPool {
  private queue: Array<() => Promise<unknown>> = []
  private running = 0
  private readonly maxConcurrent: number
  private readonly delayMs: number  // Between batch starts

  constructor(maxConcurrent = 3, delayMs = 500) {
    this.maxConcurrent = maxConcurrent
    this.delayMs = delayMs
  }

  async run<T>(fn: () => Promise<T>): Promise<T> {
    // Wait if at capacity
    while (this.running >= this.maxConcurrent) {
      await new Promise(resolve => setTimeout(resolve, 100))
    }

    this.running++
    try {
      return await fn()
    } finally {
      this.running--
      await new Promise(resolve => setTimeout(resolve, this.delayMs))
    }
  }
}
```

## Aggregating Results

Parallel results come in arbitrary order. Always track by ID:

```ts
// Wrong: assumes order is preserved
const [firstResult, secondResult] = await Promise.all([taskA, taskB])

// Right: map by ID
const results = await runParallel(tasks)
const resultById = new Map(results.map(r => [r.id, r]))

for (const task of originalTasks) {
  const result = resultById.get(task.id)
  if (result?.error) {
    console.error(`Task ${task.id} failed:`, result.error)
  } else {
    processResult(task, result!.output)
  }
}
```

## Cost Consideration

Parallel agents run faster but cost the same as sequential agents (total tokens × price). Parallelism trades money for time. Benchmark:

- 10 agents × 5s each = 5s total, 10× cost vs 1 sequential agent
- Appropriate when: user is waiting, tasks are independent, time matters
- Avoid when: batch processing overnight, sequential is acceptable
