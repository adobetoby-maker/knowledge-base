# Agent State Machines

## Why State Machines for Agents

Agents performing multi-step tasks benefit from explicit state tracking:
- Prevents re-doing completed steps after interruption
- Makes recovery from partial failure possible
- Gives clear progress indicators
- Prevents infinite loops (state transitions are bounded)

## Simple State Machine for Batch Jobs

```typescript
// types/batch-state.ts
type TaskState = 
  | 'pending'
  | 'in_progress'
  | 'completed'
  | 'failed'
  | 'needs_review'

interface Task {
  id: string
  state: TaskState
  startedAt?: string
  completedAt?: string
  error?: string
  attempts: number
}

interface BatchState {
  runId: string
  startedAt: string
  tasks: Record<string, Task>
}
```

```typescript
// state-machine.ts
class BatchStateMachine {
  private state: BatchState
  private stateFile: string
  
  constructor(stateFile: string) {
    this.stateFile = stateFile
    this.state = this.load()
  }
  
  private load(): BatchState {
    if (fs.existsSync(this.stateFile)) {
      return JSON.parse(fs.readFileSync(this.stateFile, 'utf-8'))
    }
    return { runId: Date.now().toString(), startedAt: new Date().toISOString(), tasks: {} }
  }
  
  private save() {
    fs.writeFileSync(this.stateFile, JSON.stringify(this.state, null, 2))
  }
  
  start(taskId: string) {
    this.state.tasks[taskId] = {
      id: taskId,
      state: 'in_progress',
      startedAt: new Date().toISOString(),
      attempts: (this.state.tasks[taskId]?.attempts ?? 0) + 1,
    }
    this.save()
  }
  
  complete(taskId: string) {
    this.state.tasks[taskId].state = 'completed'
    this.state.tasks[taskId].completedAt = new Date().toISOString()
    this.save()
  }
  
  fail(taskId: string, error: string) {
    const task = this.state.tasks[taskId]
    task.state = task.attempts >= 3 ? 'needs_review' : 'failed'
    task.error = error
    this.save()
  }
  
  isPending(taskId: string): boolean {
    const task = this.state.tasks[taskId]
    return !task || task.state === 'pending' || task.state === 'failed'
  }
  
  summary() {
    const tasks = Object.values(this.state.tasks)
    return {
      total: tasks.length,
      completed: tasks.filter(t => t.state === 'completed').length,
      failed: tasks.filter(t => t.state === 'failed').length,
      needsReview: tasks.filter(t => t.state === 'needs_review').length,
      pending: tasks.filter(t => t.state === 'pending').length,
    }
  }
}
```

## Usage in Batch Runner

```typescript
const sm = new BatchStateMachine('/tmp/batch-state.json')

for (const task of tasks) {
  if (!sm.isPending(task.id)) {
    console.log(`Skipping ${task.id} (${sm.getState(task.id).state})`)
    continue
  }
  
  sm.start(task.id)
  
  try {
    await executeTask(task)
    sm.complete(task.id)
  } catch (error) {
    sm.fail(task.id, error.message)
  }
}

console.log(sm.summary())
```

## Agent Flow State Transitions

For interactive agents handling multi-step workflows:

```typescript
type AgentState = 
  | { phase: 'idle' }
  | { phase: 'researching'; query: string }
  | { phase: 'planning'; findings: string[] }
  | { phase: 'executing'; plan: Step[]; currentStep: number }
  | { phase: 'verifying'; results: string[] }
  | { phase: 'complete'; summary: string }
  | { phase: 'blocked'; reason: string; humanRequired: true }

// Valid transitions:
const TRANSITIONS: Record<AgentState['phase'], AgentState['phase'][]> = {
  idle: ['researching'],
  researching: ['planning', 'blocked'],
  planning: ['executing', 'blocked'],
  executing: ['verifying', 'blocked'],
  verifying: ['complete', 'executing'],  // can loop back if verification fails
  complete: ['idle'],
  blocked: ['idle'],  // human resolves, then reset
}

function canTransition(from: AgentState['phase'], to: AgentState['phase']): boolean {
  return TRANSITIONS[from]?.includes(to) ?? false
}
```

## Resumable State (Across Invocations)

For overnight batch jobs that write state to disk:

```typescript
// On startup: check if there's a saved state:
const STATE_FILE = '/tmp/seo-batch-progress.json'

interface Progress {
  completed: string[]
  failed: { slug: string; error: string }[]
  needsReview: { slug: string; warnings: string[] }[]
  lastUpdated: string
}

function loadProgress(): Progress {
  if (fs.existsSync(STATE_FILE)) {
    return JSON.parse(fs.readFileSync(STATE_FILE, 'utf-8'))
  }
  return { completed: [], failed: [], needsReview: [], lastUpdated: '' }
}

// Skip already-completed tasks:
const progress = loadProgress()
const remaining = allTasks.filter(t => !progress.completed.includes(t.id))
console.log(`Resuming: ${progress.completed.length} done, ${remaining.length} remaining`)
```

## When NOT to Use State Machines

Simple sequential scripts that run start-to-finish without interruption don't need state machines — the overhead isn't worth it. Use state machines when:

- The job might be interrupted (overnight batch, cron job that could timeout)
- Steps have failure rates > ~5% (retry logic is needed)
- The job takes > 10 minutes (resumability matters)
- Multiple steps can fail independently
