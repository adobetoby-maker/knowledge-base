# Agents: Multi-Model Routing

## The Problem

Using the same model for every task wastes money on simple operations and under-serves complex ones. A model routing layer directs each task to the appropriate model based on: complexity, volume, latency requirements, and cost tolerance.

## The Routing Decision

```
TASK TYPE                              → MODEL

"do X to each item in this list"       → haiku
 String replacements across files      → haiku
 Image download / rename / move        → haiku
 git add / commit / push               → haiku
 npm install, format checks            → haiku
 JSON transformation                   → haiku

 New React component from spec         → sonnet
 Multi-file debugging                  → sonnet
 Content writing (articles, copy)      → sonnet
 Architecture decisions                → sonnet
 Agent orchestration logic             → sonnet
 Code review with context              → sonnet

 High-stakes product strategy          → opus
 Complex multi-part reasoning          → opus
 Architecture review for large system  → opus
```

## Router Function

```ts
type TaskComplexity = 'mechanical' | 'reasoning' | 'strategic'

interface RoutedTask {
  description: string
  inputSize?: number   // approximate tokens
  outputSize?: number
  requiresLongContext?: boolean
}

function routeTask(task: RoutedTask): {
  model: string
  reason: string
} {
  const {
    description,
    inputSize = 0,
    outputSize = 0,
    requiresLongContext = false,
  } = task

  const lower = description.toLowerCase()

  // Mechanical pattern matching → Haiku
  const mechanicalPatterns = [
    'rename', 'move', 'copy', 'delete',
    'replace all', 'format', 'convert',
    'download', 'install', 'commit', 'push',
    'each file', 'each item', 'for each',
    'add import', 'fix lint',
  ]
  if (mechanicalPatterns.some(p => lower.includes(p)) && !requiresLongContext) {
    return { model: 'claude-haiku-4-5', reason: 'mechanical task' }
  }

  // Strategic → Opus
  const strategicPatterns = [
    'architecture', 'strategy', 'design system',
    'product decision', 'trade-off analysis', 'security audit',
  ]
  if (strategicPatterns.some(p => lower.includes(p))) {
    return { model: 'claude-opus-4-7', reason: 'strategic reasoning required' }
  }

  // Default → Sonnet
  return { model: 'claude-sonnet-4-6', reason: 'balanced task' }
}
```

## Cost Comparison (per 1M tokens)

```ts
const MODEL_COSTS = {
  'claude-haiku-4-5': {
    input: 0.25,   // USD per 1M tokens
    output: 1.25,
  },
  'claude-sonnet-4-6': {
    input: 3.00,
    output: 15.00,
  },
  'claude-opus-4-7': {
    input: 15.00,
    output: 75.00,
  },
}

// For 1000 items requiring ~100 input tokens, ~200 output tokens each:
// Haiku:  (100K / 1M * 0.25) + (200K / 1M * 1.25) = $0.275
// Sonnet: (100K / 1M * 3.00) + (200K / 1M * 15.0) = $3.30
// Opus:   (100K / 1M * 15.0) + (200K / 1M * 75.0) = $16.50
// Haiku is 12x cheaper than Sonnet for this batch
```

## Agent Spawn with Model Selection

```ts
// Main orchestrator (Sonnet): decides what work to do
// Spawns Haiku workers: mechanical tasks
// Escalates to Opus: strategic decisions only

interface AgentTask {
  type: 'mechanical' | 'content' | 'strategic'
  payload: string
}

async function orchestrate(tasks: AgentTask[]) {
  const mechanical = tasks.filter(t => t.type === 'mechanical')
  const content = tasks.filter(t => t.type === 'content')
  const strategic = tasks.filter(t => t.type === 'strategic')

  // Mechanical in parallel with Haiku
  await Promise.all(mechanical.map(task =>
    Agent({
      model: 'haiku',
      prompt: task.payload,
      // ...
    })
  ))

  // Content sequentially with Sonnet (rate limits)
  for (const task of content) {
    await Agent({ model: 'sonnet', prompt: task.payload })
  }

  // Strategic one at a time with Opus
  for (const task of strategic) {
    await Agent({ model: 'opus', prompt: task.payload })
  }
}
```

## Local Model Routing

For overnight batch jobs where network latency and API cost matter more than quality:

```ts
const LOCAL_MODELS = {
  articles: 'llama3.2:8b',       // Ollama: article generation
  translations: 'qwen2.5:7b',    // Ollama: multilingual content
  code_review: 'codellama:13b',  // Ollama: code analysis
}

function routeToLocal(task: string): string | null {
  if (process.env.USE_LOCAL_MODELS !== 'true') return null

  if (task.includes('article') || task.includes('blog')) {
    return LOCAL_MODELS.articles
  }
  if (task.includes('translate') || task.includes('spanish') || task.includes('portuguese')) {
    return LOCAL_MODELS.translations
  }
  return null
}

async function callModel(model: string | null, prompt: string): Promise<string> {
  if (model && model.includes(':')) {
    // Local Ollama model
    const res = await fetch('http://localhost:11434/api/generate', {
      method: 'POST',
      body: JSON.stringify({ model, prompt, stream: false }),
    })
    const data = await res.json()
    return data.response
  }

  // Cloud model via Anthropic API
  const msg = await client.messages.create({
    model: model ?? 'claude-haiku-4-5',
    max_tokens: 2048,
    messages: [{ role: 'user', content: prompt }],
  })
  return msg.content[0].type === 'text' ? msg.content[0].text : ''
}
```

## When to NOT Route

Don't route if:
- The task is ambiguous — default to Sonnet and monitor
- The cost difference is small (< $0.10 total) — the routing overhead isn't worth it
- You haven't verified that Haiku produces acceptable quality for the task type
- The task requires nuanced judgment about its own complexity
