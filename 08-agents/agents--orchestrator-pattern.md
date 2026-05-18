# Agent: Orchestrator Pattern

## Overview

The orchestrator pattern uses a controlling agent to decompose complex tasks, assign subtasks to specialized worker agents, and synthesize their results. The orchestrator itself doesn't do the work — it plans, delegates, and integrates. This enables parallelism, specialization, and progressive refinement.

## When to Use Orchestration

Use orchestration when:
- The task has multiple independent subtasks that benefit from parallel execution
- Different subtasks require different expertise (research vs coding vs writing)
- The task is too long for a single context window
- You want auditability of each step

Don't use orchestration for:
- Simple single-step tasks
- Tasks where coordination overhead exceeds the benefit
- Tasks where context from one step is immediately required by the next (sequential chains, not orchestration)

## Basic Orchestrator Structure

```ts
interface WorkerTask {
  id: string
  type: string
  input: string
  priority: number
}

interface WorkerResult {
  taskId: string
  success: boolean
  output: string
  error?: string
}

async function orchestrate(userGoal: string): Promise<string> {
  // Step 1: Plan — decompose the goal into tasks
  const tasks = await planTasks(userGoal)

  // Step 2: Execute — run tasks (parallelize independent ones)
  const results = await executeTasks(tasks)

  // Step 3: Synthesize — combine results into final output
  return await synthesize(userGoal, tasks, results)
}
```

## Planning Step

```ts
async function planTasks(goal: string): Promise<WorkerTask[]> {
  const response = await llm.chat({
    model: 'claude-sonnet-4-6',
    messages: [{
      role: 'user',
      content: `Break down this goal into concrete subtasks. Return JSON only.

Goal: "${goal}"

Return: {
  "tasks": [
    {
      "id": "task-1",
      "type": "research|code|write|analyze",
      "input": "specific task description",
      "dependencies": [],   // IDs of tasks that must complete first
      "priority": 1         // execution order for sequential tasks
    }
  ]
}`
    }],
    options: { temperature: 0 },
  })

  const parsed = JSON.parse(extractJson(response))
  return parsed.tasks
}
```

## Parallel Execution

```ts
async function executeTasks(tasks: WorkerTask[]): Promise<WorkerResult[]> {
  // Group independent tasks for parallel execution
  const layers = topologicalSort(tasks)  // [[t1, t2], [t3], [t4, t5]]
  const results: WorkerResult[] = []
  const resultMap = new Map<string, WorkerResult>()

  for (const layer of layers) {
    const layerResults = await Promise.all(
      layer.map(task => executeWorker(task, resultMap))
    )
    layerResults.forEach(r => resultMap.set(r.taskId, r))
    results.push(...layerResults)
  }

  return results
}

async function executeWorker(task: WorkerTask, priorResults: Map<string, WorkerResult>): Promise<WorkerResult> {
  // Build context from dependency results
  const context = task.dependencies
    .map(dep => priorResults.get(dep))
    .filter(Boolean)
    .map(r => `[${r!.taskId} result]: ${r!.output}`)
    .join('\n\n')

  const input = context ? `Prior results:\n${context}\n\nYour task: ${task.input}` : task.input

  try {
    const output = await callWorkerAgent(task.type, input)
    return { taskId: task.id, success: true, output }
  } catch (error) {
    return { taskId: task.id, success: false, output: '', error: (error as Error).message }
  }
}
```

## Topological Sort (Dependency Resolution)

```ts
function topologicalSort(tasks: WorkerTask[]): WorkerTask[][] {
  const layers: WorkerTask[][] = []
  const completed = new Set<string>()

  while (completed.size < tasks.length) {
    const layer = tasks.filter(t =>
      !completed.has(t.id) &&
      t.dependencies.every(dep => completed.has(dep))
    )

    if (layer.length === 0) {
      throw new Error('Circular dependency in task graph')
    }

    layers.push(layer)
    layer.forEach(t => completed.add(t.id))
  }

  return layers
}
```

## Synthesis Step

```ts
async function synthesize(goal: string, tasks: WorkerTask[], results: WorkerResult[]): Promise<string> {
  const successfulResults = results.filter(r => r.success)
  const failedTasks = results.filter(r => !r.success)

  const context = successfulResults
    .map(r => {
      const task = tasks.find(t => t.id === r.taskId)!
      return `### ${task.type}: ${task.input}\n${r.output}`
    })
    .join('\n\n')

  const response = await llm.chat({
    messages: [{
      role: 'user',
      content: `Synthesize these subtask results into a cohesive response for the original goal.

Original goal: ${goal}

Subtask results:
${context}

${failedTasks.length > 0 ? `Note: ${failedTasks.length} subtask(s) failed: ${failedTasks.map(r => r.taskId).join(', ')}` : ''}

Provide a complete, integrated response.`
    }],
  })

  return response.message.content
}
```

## Key Rules

- The orchestrator should not do domain work itself — it plans and integrates, workers execute.
- Pass only the relevant prior results to each worker, not the full context — full context blows the context window on long pipelines.
- Topological sort enables maximum parallelism while respecting dependencies — don't serialize tasks that could run in parallel.
- Failed worker tasks should degrade gracefully — synthesize with available results rather than failing the entire orchestration.
- Log task execution start/end with timing — orchestration jobs are long-running and need observability to debug.
