# Agent Batch Orchestration

## The Pattern

Batch orchestration is for processing many similar items (generate N articles, update N records, audit N files) where each item is independent.

## The Orchestrator-Worker Model

```
Orchestrator (Sonnet/main session):
  - Reads task manifest
  - Decides routing (local vs cloud, which model)
  - Spawns workers
  - Collects results
  - Writes final report

Workers (Haiku agents, spawned in parallel):
  - Receive a single task
  - Execute it
  - Return result
  - Done — no state carried over
```

## Task Manifest Format

```typescript
interface BatchManifest {
  jobId: string
  tasks: BatchTask[]
  globalContext?: string  // shared context for all tasks
  options: {
    maxParallel: number      // workers running at once
    delayBetweenMs: number   // rate limiting
    maxRetries: number
    model: 'haiku' | 'sonnet' | 'local'
  }
}

interface BatchTask {
  id: string
  type: string
  input: Record<string, unknown>
  outputFile?: string        // where to write result
  verifyCommand?: string     // shell command to verify output
}
```

## Spawning Workers with Agent Tool

```typescript
// In the orchestrator:
async function runBatch(manifest: BatchManifest): Promise<void> {
  const progress = loadProgress(manifest.jobId)
  const remaining = manifest.tasks.filter(t => !progress.completed.includes(t.id))
  
  // Process in batches of maxParallel:
  for (let i = 0; i < remaining.length; i += manifest.options.maxParallel) {
    const batch = remaining.slice(i, i + manifest.options.maxParallel)
    
    // Run batch in parallel:
    const results = await Promise.all(batch.map(task => runTask(task, manifest)))
    
    // Record results:
    for (const result of results) {
      if (result.success) {
        progress.completed.push(result.taskId)
      } else {
        progress.failed.push({ id: result.taskId, error: result.error })
      }
    }
    
    saveProgress(progress)
    
    // Rate limit between batches:
    await new Promise(r => setTimeout(r, manifest.options.delayBetweenMs))
  }
}
```

## Worker Prompts — Be Explicit

Workers receive a single invocation with no prior context. The prompt must be completely self-contained:

```typescript
function buildWorkerPrompt(task: BatchTask, globalContext: string): string {
  return `
You are processing one task from a batch job. Complete it exactly as specified and return ONLY the requested output — no commentary.

${globalContext}

TASK:
Type: ${task.type}
ID: ${task.id}
Input: ${JSON.stringify(task.input, null, 2)}

OUTPUT REQUIREMENTS:
- Return JSON matching this exact structure: {"result": "...", "metadata": {...}}
- If you cannot complete the task, return: {"error": "brief reason"}
- Nothing else — no explanation, no preamble
`
}
```

## Fan-Out Then Fan-In

For tasks that require aggregating results:

```typescript
// Fan-out: generate all sections independently
const sectionResults = await Promise.all([
  generateIntro(slug),
  generateBenefits(slug),
  generateProcess(slug),
  generateCTA(slug),
])

// Fan-in: combine sections into final article
const article = {
  slug,
  body: sectionResults.map(r => r.text).join('\n\n'),
  metadata: combineMetadata(sectionResults),
}
```

## Idempotency at Orchestrator Level

```typescript
// Skip tasks already completed — idempotent:
const shouldProcess = (taskId: string, progress: Progress): boolean => {
  if (progress.completed.includes(taskId)) return false
  if (progress.permanentlyFailed.includes(taskId)) return false  // exhausted retries
  return true
}
```

## Cost Tracking

For cloud workers, track token usage:

```typescript
interface WorkerResult {
  taskId: string
  success: boolean
  output?: unknown
  error?: string
  tokensUsed?: {
    input: number
    output: number
    model: string
  }
}

// In final report:
const totalCost = results.reduce((sum, r) => {
  if (!r.tokensUsed) return sum
  const rates = {
    'claude-haiku-4-5': { input: 0.8, output: 4.0 },  // per million tokens
    'claude-sonnet-4-6': { input: 3.0, output: 15.0 },
  }
  const rate = rates[r.tokensUsed.model]
  if (!rate) return sum
  return sum + (r.tokensUsed.input / 1_000_000 * rate.input) + (r.tokensUsed.output / 1_000_000 * rate.output)
}, 0)

console.log(`Total API cost: $${totalCost.toFixed(4)}`)
```

## When to Not Use Batch Orchestration

Don't build batch orchestration for:
- Tasks that run once (just run it directly)
- Tasks with < 10 items (serial execution is fine)
- Tasks where order matters and one failure should stop the rest
- Tasks that require real-time human review after each item
