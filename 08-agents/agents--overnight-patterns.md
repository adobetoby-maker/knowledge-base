# Agent Overnight Operation Patterns

## The Fundamental Difference from Interactive Use

Interactive agents have a human watching, able to correct mistakes in real time. Overnight agents run unattended for hours. Every decision pattern must account for this.

**Interactive**: fail fast, ask clarifying questions, make assumptions explicit.
**Overnight**: recover from errors, skip unresolvable tasks, never block on human input.

## The Non-Blocking Rule

An overnight agent must NEVER block waiting for human input. Any state where the agent is stuck and waiting means the entire night's work is lost.

```typescript
// Decision tree for every blocking situation:
// 1. Can I resolve this with available context? → resolve and continue
// 2. Is this task skip-able? → skip with NEEDS_HUMAN note, continue
// 3. Is this a fatal configuration error? → write NEEDS_HUMAN.md, exit cleanly

// NEVER: prompt for input, wait for a response
```

## Progress File Pattern

Always write progress to disk. This enables:
- Resumability after crash
- Human inspection of what happened
- Debugging without re-running

```typescript
// scripts/seo-batch.ts
const PROGRESS_FILE = '/tmp/seo-batch-progress.json'

interface Progress {
  startedAt: string
  completed: string[]
  failed: { slug: string; error: string; timestamp: string }[]
  needsReview: { slug: string; warnings: string[] }[]
  lastProcessedAt: string
}

function loadProgress(): Progress {
  if (fs.existsSync(PROGRESS_FILE)) {
    return JSON.parse(fs.readFileSync(PROGRESS_FILE, 'utf-8'))
  }
  return {
    startedAt: new Date().toISOString(),
    completed: [],
    failed: [],
    needsReview: [],
    lastProcessedAt: '',
  }
}

function saveProgress(progress: Progress) {
  progress.lastProcessedAt = new Date().toISOString()
  fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2))
}
```

## Checkpoint Every N Tasks

Save progress after every task, not just at the end:

```typescript
for (const task of tasks) {
  if (progress.completed.includes(task.id)) {
    console.log(`Skipping ${task.id} (already done)`)
    continue
  }
  
  try {
    await processTask(task)
    progress.completed.push(task.id)
  } catch (error) {
    progress.failed.push({ slug: task.id, error: error.message, timestamp: new Date().toISOString() })
  }
  
  // Save after EVERY task:
  saveProgress(progress)
  
  // Rate limiting:
  await new Promise(r => setTimeout(r, 1000))
}
```

If the machine crashes at 3 AM, the next run picks up where it left off.

## Error Budget

Don't abort on first error — set a threshold:

```typescript
const MAX_CONSECUTIVE_FAILURES = 5
let consecutiveFailures = 0

for (const task of tasks) {
  try {
    await processTask(task)
    consecutiveFailures = 0  // reset on success
  } catch (error) {
    consecutiveFailures++
    progress.failed.push({ slug: task.id, error: error.message, timestamp: new Date().toISOString() })
    
    if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
      // Something systemic is wrong — abort
      writeNeedsHuman('Too many consecutive failures', {
        lastTask: task.id,
        lastError: error.message,
        consecutiveCount: consecutiveFailures,
      })
      process.exit(1)
    }
  }
}
```

5 consecutive failures suggests a systemic problem (API down, config error) that won't self-resolve. Abort and flag.

## NEEDS_HUMAN.md Pattern

When a problem requires human intervention:

```typescript
function writeNeedsHuman(summary: string, details: Record<string, unknown>) {
  const content = `# NEEDS HUMAN REVIEW

## ${summary}

**Time**: ${new Date().toISOString()}
**Details**:
${JSON.stringify(details, null, 2)}

## What to do
1. Check the error details above
2. Resolve the underlying issue
3. Delete this file and re-run the batch
`
  fs.writeFileSync('/tmp/NEEDS_HUMAN.md', content)
  console.error(`NEEDS HUMAN: ${summary}`)
}
```

## Rate Limiting for API Calls

Overnight jobs often make hundreds of API calls. Space them out to avoid rate limits:

```typescript
const RATE_LIMITS = {
  anthropic_haiku: 1000,   // 1 second between calls (stays well within rate limits)
  supabase_rpc: 100,        // 100ms between DB calls
  external_api: 2000,       // 2 seconds to be safe
}

// Utility:
async function withDelay<T>(fn: () => Promise<T>, delayMs: number): Promise<T> {
  const result = await fn()
  await new Promise(r => setTimeout(r, delayMs))
  return result
}
```

## End-of-Run Report

Always generate a summary:

```typescript
function printSummary(progress: Progress, tasks: Task[]) {
  const duration = Date.now() - new Date(progress.startedAt).getTime()
  const minutes = Math.round(duration / 60000)
  
  console.log('\n═══════════════════════════════════')
  console.log('BATCH COMPLETE')
  console.log(`Duration: ${minutes} minutes`)
  console.log(`Completed: ${progress.completed.length}/${tasks.length}`)
  console.log(`Failed: ${progress.failed.length}`)
  console.log(`Needs review: ${progress.needsReview.length}`)
  
  if (progress.failed.length > 0) {
    console.log('\nFailed tasks:')
    progress.failed.forEach(f => console.log(`  × ${f.slug}: ${f.error}`))
  }
  console.log('═══════════════════════════════════\n')
}
```
