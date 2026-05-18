# Agent Pattern: Loop Detection

## Overview

Autonomous agents can get stuck in loops — repeating the same action, querying the same resource, or cycling between states without progress. Loop detection breaks the cycle before it exhausts budget or blocks a pipeline.

## Common Loop Patterns

1. **Retry loop**: Agent fails, retries the exact same call, fails again, repeats indefinitely
2. **Oscillation**: Agent alternates between two states ("add feature X" → "remove feature X" → "add feature X")
3. **Redundant query loop**: Agent asks the same question to different sub-agents, collects identical answers, asks again
4. **Progress illusion**: Agent generates text claiming progress without actually calling tools

## Detection Strategies

### Action Hash Fingerprinting

```ts
import { createHash } from 'crypto'

interface AgentAction {
  type: string
  params: Record<string, unknown>
}

class LoopDetector {
  private actionHistory: string[] = []
  private maxHistorySize = 20
  private windowSize = 5  // Check last N actions for repetition

  fingerprint(action: AgentAction): string {
    return createHash('md5')
      .update(JSON.stringify({ type: action.type, params: action.params }))
      .digest('hex')
      .slice(0, 8)
  }

  check(action: AgentAction): { isLoop: boolean; reason?: string } {
    const fp = this.fingerprint(action)
    const recentWindow = this.actionHistory.slice(-this.windowSize)

    // Exact repeat in recent window
    if (recentWindow.includes(fp)) {
      return {
        isLoop: true,
        reason: `Action "${action.type}" repeated within last ${this.windowSize} steps`,
      }
    }

    // Oscillation: current matches 2 steps ago
    const twoStepsBack = this.actionHistory[this.actionHistory.length - 2]
    if (fp === twoStepsBack) {
      return { isLoop: true, reason: `Oscillation detected: "${action.type}" alternating` }
    }

    this.actionHistory.push(fp)
    if (this.actionHistory.length > this.maxHistorySize) {
      this.actionHistory.shift()
    }

    return { isLoop: false }
  }
}
```

## Progress Tracking

```ts
class ProgressTracker {
  private stateSnapshots: string[] = []
  private stepsWithoutProgress = 0
  private maxStepsWithoutProgress = 5

  captureState(state: object): void {
    const snapshot = JSON.stringify(state)
    const isProgressMade = this.stateSnapshots.length === 0 ||
      snapshot !== this.stateSnapshots[this.stateSnapshots.length - 1]

    if (isProgressMade) {
      this.stepsWithoutProgress = 0
    } else {
      this.stepsWithoutProgress++
    }

    this.stateSnapshots.push(snapshot)
    if (this.stateSnapshots.length > 10) this.stateSnapshots.shift()
  }

  isStuck(): boolean {
    return this.stepsWithoutProgress >= this.maxStepsWithoutProgress
  }

  getStuckMessage(): string {
    return `No state change detected in last ${this.stepsWithoutProgress} steps`
  }
}
```

## Integration in Agent Loop

```ts
async function runAgent(initialTask: string, maxSteps = 50): Promise<AgentResult> {
  const loopDetector = new LoopDetector()
  const progressTracker = new ProgressTracker()
  let state = { task: initialTask, completed: false, steps: [] as AgentStep[] }

  for (let step = 0; step < maxSteps; step++) {
    const action = await planNextAction(state)

    // Check for loop before executing
    const loopCheck = loopDetector.check(action)
    if (loopCheck.isLoop) {
      // Inject correction into context before re-planning
      const correction = await resolveLoop(state, loopCheck.reason!)
      state = { ...state, loopCorrectionApplied: correction }
      continue
    }

    const result = await executeAction(action)
    state = applyResult(state, result)

    progressTracker.captureState(state)
    if (progressTracker.isStuck()) {
      console.warn(`Agent stuck: ${progressTracker.getStuckMessage()}`)
      break
    }

    if (state.completed) break
  }

  return state
}

async function resolveLoop(state: AgentState, reason: string): Promise<string> {
  // Ask model to break the loop with explicit instruction
  const resolution = await callModel(`
The agent is stuck in a loop: ${reason}

Current state: ${JSON.stringify(state, null, 2)}

What is a DIFFERENT approach that hasn't been tried yet?
Choose a completely different strategy — don't repeat any recent action.
`)
  return resolution
}
```

## Step Limit as Hard Backstop

Always set a maximum step count regardless of loop detection. Loop detection catches known patterns; the step limit catches unknown ones. For a task expected to complete in 10 steps, set the limit at 25–30. For a task with unknown complexity, start at 50.

Log step counts per task type. If a task consistently hits 40+ steps, the task decomposition or tools are wrong, not the step limit.

## Tool Call Deduplication

For agents using external tools (API calls, database queries), track recent tool calls and skip identical calls within a short window:

```ts
const toolCallCache = new Map<string, { result: unknown; timestamp: number }>()
const CACHE_WINDOW_MS = 60_000  // 1 minute

async function callTool(name: string, params: object): Promise<unknown> {
  const key = `${name}:${JSON.stringify(params)}`
  const cached = toolCallCache.get(key)

  if (cached && Date.now() - cached.timestamp < CACHE_WINDOW_MS) {
    console.log(`Deduplicating tool call: ${name}`)
    return cached.result
  }

  const result = await executeToolCall(name, params)
  toolCallCache.set(key, { result, timestamp: Date.now() })
  return result
}
```

This prevents API rate-limit exhaustion when an agent repeatedly calls the same external resource with identical parameters.
