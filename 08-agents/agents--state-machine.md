# Agent: State Machine Pattern

## Overview

Complex agents benefit from an explicit state machine to manage their lifecycle. A state machine makes transitions explicit and auditable: the agent can only move from valid states to valid states. This prevents silent failures where an agent gets stuck, produces confusing logs, or takes invalid actions.

## Agent States

```ts
type AgentState =
  | 'idle'
  | 'planning'
  | 'executing'
  | 'waiting_for_tool'
  | 'reviewing'
  | 'complete'
  | 'failed'
  | 'waiting_for_human'

interface AgentContext {
  sessionId: string
  goal: string
  plan: string[]
  currentStep: number
  results: StepResult[]
  error?: string
  pendingApproval?: PendingApproval
}
```

## Transition Table

```ts
type Transition = {
  from: AgentState
  to: AgentState
  on: string  // event name
}

const TRANSITIONS: Transition[] = [
  { from: 'idle',              on: 'START',         to: 'planning' },
  { from: 'planning',          on: 'PLAN_READY',    to: 'executing' },
  { from: 'planning',          on: 'ERROR',         to: 'failed' },
  { from: 'executing',         on: 'TOOL_CALL',     to: 'waiting_for_tool' },
  { from: 'executing',         on: 'NEED_APPROVAL', to: 'waiting_for_human' },
  { from: 'executing',         on: 'STEP_COMPLETE',  to: 'reviewing' },
  { from: 'executing',         on: 'ERROR',         to: 'failed' },
  { from: 'waiting_for_tool',  on: 'TOOL_RESULT',   to: 'executing' },
  { from: 'waiting_for_tool',  on: 'TOOL_ERROR',    to: 'failed' },
  { from: 'waiting_for_human', on: 'APPROVED',      to: 'executing' },
  { from: 'waiting_for_human', on: 'REJECTED',      to: 'failed' },
  { from: 'reviewing',         on: 'CONTINUE',      to: 'executing' },
  { from: 'reviewing',         on: 'DONE',          to: 'complete' },
]

function transition(current: AgentState, event: string): AgentState {
  const t = TRANSITIONS.find(t => t.from === current && t.on === event)
  if (!t) throw new Error(`Invalid transition: ${current} + ${event}`)
  return t.to
}
```

## State Machine Implementation

```ts
class AgentStateMachine {
  private state: AgentState = 'idle'
  private context: AgentContext

  constructor(goal: string) {
    this.context = {
      sessionId: crypto.randomUUID(),
      goal,
      plan: [],
      currentStep: 0,
      results: [],
    }
  }

  async dispatch(event: string, data?: unknown): Promise<void> {
    const nextState = transition(this.state, event)
    console.log(`[${this.context.sessionId}] ${this.state} → ${nextState} (${event})`)

    this.state = nextState
    await this.persist()  // Checkpoint after every transition

    await this.onEnterState(nextState, data)
  }

  private async onEnterState(state: AgentState, data?: unknown) {
    switch (state) {
      case 'planning':
        await this.runPlanning()
        break
      case 'executing':
        await this.runNextStep()
        break
      case 'reviewing':
        await this.reviewProgress()
        break
      case 'complete':
        await this.onComplete()
        break
      case 'failed':
        await this.onFailed(data as Error)
        break
    }
  }

  private async runPlanning() {
    try {
      const plan = await generatePlan(this.context.goal)
      this.context.plan = plan
      await this.dispatch('PLAN_READY')
    } catch (e) {
      this.context.error = (e as Error).message
      await this.dispatch('ERROR', e)
    }
  }

  private async runNextStep() {
    if (this.context.currentStep >= this.context.plan.length) {
      await this.dispatch('DONE')
      return
    }

    const step = this.context.plan[this.context.currentStep]
    try {
      const result = await executeStep(step, this.context)
      this.context.results.push({ step, result, success: true })
      this.context.currentStep++
      await this.dispatch('STEP_COMPLETE', result)
    } catch (e) {
      this.context.error = (e as Error).message
      await this.dispatch('ERROR', e)
    }
  }

  private async persist() {
    // Checkpoint to Redis/DB — allows resumption after crash
    await redis.set(
      `agent:${this.context.sessionId}`,
      JSON.stringify({ state: this.state, context: this.context }),
      'EX',
      3600  // 1 hour TTL
    )
  }

  static async resume(sessionId: string): Promise<AgentStateMachine | null> {
    const data = await redis.get(`agent:${sessionId}`)
    if (!data) return null
    const { state, context } = JSON.parse(data)
    const machine = new AgentStateMachine(context.goal)
    machine.state = state
    machine.context = context
    return machine
  }
}
```

## Starting the Agent

```ts
async function runAgent(goal: string): Promise<AgentResult> {
  const machine = new AgentStateMachine(goal)
  await machine.dispatch('START')

  // Wait for completion or failure
  return waitForCompletion(machine.context.sessionId)
}
```

## Key Rules

- Persist state after every transition — if the process crashes, the agent can resume from the last checkpoint.
- Invalid transitions should throw, not silently do nothing — invalid transitions indicate a bug in the agent logic.
- The `waiting_for_human` state enables async human-in-the-loop without blocking the process — the agent pauses, stores its state, and resumes when approved.
- Log every state transition with timestamp and session ID — this is the audit trail for debugging agent behavior.
- States should be named for what the agent IS (in this state), not what it's doing — `waiting_for_tool` not `calling_tool`.
