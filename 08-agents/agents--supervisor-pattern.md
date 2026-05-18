# Agent Pattern: Supervisor

## Overview

A supervisor agent orchestrates specialized sub-agents, delegating tasks based on capability, tracking progress, and aggregating results. The supervisor doesn't do the work — it decides who does, monitors their output, and handles failures.

## Core Responsibility Split

```
Supervisor responsibilities:
  - Decompose task into subtasks
  - Route subtasks to appropriate specialist agents
  - Monitor progress and handle timeouts
  - Re-route or retry failed subtasks
  - Aggregate and validate results
  - Present coherent final output

Specialist agent responsibilities:
  - Execute one specific type of task
  - Return structured output
  - Signal success/failure clearly
  - Not manage other agents
```

## Supervisor Implementation

```ts
interface SubAgent {
  name: string
  description: string
  capabilities: string[]
  run: (task: string, context?: string) => Promise<AgentOutput>
}

interface AgentOutput {
  success: boolean
  result?: string
  error?: string
  metadata?: Record<string, unknown>
}

interface SupervisorTask {
  id: string
  description: string
  assignedTo?: string
  status: 'pending' | 'running' | 'complete' | 'failed'
  result?: AgentOutput
  attempts: number
}

class SupervisorAgent {
  private specialists: Map<string, SubAgent>
  private maxRetries = 2

  constructor(specialists: SubAgent[]) {
    this.specialists = new Map(specialists.map(s => [s.name, s]))
  }

  async execute(goal: string): Promise<string> {
    // Step 1: Decompose goal into subtasks
    const subtasks = await this.decompose(goal)

    // Step 2: Execute subtasks (with parallelism where possible)
    const results = await this.executeSubtasks(subtasks)

    // Step 3: Synthesize results
    return await this.synthesize(goal, results)
  }

  private async decompose(goal: string): Promise<SupervisorTask[]> {
    // Use LLM to decompose, then route each task to the best agent
    const decompositionPrompt = `Goal: ${goal}

Available specialists:
${[...this.specialists.values()].map(s => `- ${s.name}: ${s.description}`).join('\n')}

Decompose this goal into independent subtasks. For each subtask, specify:
1. What needs to be done
2. Which specialist should handle it

Return JSON: { tasks: [{ id: string, description: string, assignedTo: string }] }`

    const response = await llm.complete(decompositionPrompt)
    const { tasks } = JSON.parse(response)

    return tasks.map((t: { id: string; description: string; assignedTo: string }) => ({
      ...t,
      status: 'pending' as const,
      attempts: 0,
    }))
  }

  private async executeSubtasks(tasks: SupervisorTask[]): Promise<SupervisorTask[]> {
    // Find tasks with no dependencies and run them in parallel
    await Promise.allSettled(
      tasks.map(async (task) => {
        while (task.attempts < this.maxRetries) {
          task.status = 'running'
          task.attempts++

          const specialist = this.specialists.get(task.assignedTo!)
          if (!specialist) {
            task.status = 'failed'
            task.result = { success: false, error: `No specialist: ${task.assignedTo}` }
            break
          }

          const output = await specialist.run(task.description)
          if (output.success) {
            task.status = 'complete'
            task.result = output
            break
          }

          // Failed — will retry if attempts remaining
          if (task.attempts >= this.maxRetries) {
            task.status = 'failed'
            task.result = output
          }
        }
      }),
    )

    return tasks
  }

  private async synthesize(goal: string, tasks: SupervisorTask[]): Promise<string> {
    const completedResults = tasks
      .filter(t => t.status === 'complete')
      .map(t => `Task: ${t.description}\nResult: ${t.result?.result}`)
      .join('\n\n')

    const failedTasks = tasks.filter(t => t.status === 'failed')

    const synthesisPrompt = `Goal: ${goal}

Completed tasks:
${completedResults}

${failedTasks.length > 0 ? `Failed tasks (${failedTasks.length}): ${failedTasks.map(t => t.description).join(', ')}` : ''}

Synthesize these results to accomplish the goal. Note any gaps from failed tasks.`

    return await llm.complete(synthesisPrompt)
  }
}
```

## Routing Without LLM

If task types are predictable, route with rules rather than LLM:

```ts
function routeTask(task: string, specialists: SubAgent[]): SubAgent {
  // Keyword-based routing (faster, cheaper)
  if (task.includes('search') || task.includes('find')) {
    return specialists.find(s => s.name === 'web-search')!
  }
  if (task.includes('code') || task.includes('implement')) {
    return specialists.find(s => s.name === 'code-writer')!
  }
  if (task.includes('calculate') || task.includes('analyze data')) {
    return specialists.find(s => s.name === 'data-analyst')!
  }
  // Default
  return specialists.find(s => s.name === 'general')!
}
```

Use LLM routing only when task types are truly ambiguous. Keyword routing is deterministic, fast, and free.

## Failure Escalation

When a specialist fails repeatedly, escalate:

```ts
async function handleFailure(task: SupervisorTask): Promise<AgentOutput> {
  // Try: different specialist
  const alternate = findAlternateSpecialist(task)
  if (alternate) return await alternate.run(task.description)

  // Try: simplify the task
  const simpler = await simplifiyTask(task.description)
  return await originalSpecialist.run(simpler)

  // Final: mark as partial failure, note gap in synthesis
  return { success: false, error: 'Could not complete after fallback attempts' }
}
```

Never silently ignore failures. Either handle them or surface them in the final synthesis.
