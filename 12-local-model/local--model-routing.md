# Local Model Routing

## When to Use Local vs Cloud Models

The routing decision is a cost vs capability trade-off. Local models run on the developer's machine (via Ollama) at near-zero cost per call. Cloud models cost money per token but are significantly more capable.

## Decision Tree

```
Is this task part of a batch job running overnight?
  YES → Is the output critically important (customer-facing, financial)?
         YES → Use Haiku (fast, cheap cloud, better quality)
         NO  → Can a local model do this adequately?
               YES → Use Ollama (zero cost)
               NO  → Use Haiku
  NO  → Is this a development session task?
         YES → Use Sonnet (best reasoning, interactive)
         NO  → Is it a high-stakes architectural decision?
               YES → Use Opus (rarely needed)
               NO  → Use Sonnet
```

## Local Model Capabilities by Task

| Task | Use Local? | Why |
|---|---|---|
| Generate boilerplate code (known patterns) | Yes | Pattern matching, not reasoning |
| Write SEO article from outline | Maybe | Quality varies — verify output |
| Debug TypeScript error | No | Requires understanding complex types |
| Rename variables across files | Yes | Mechanical task |
| Design system architecture | No | Requires nuanced trade-off reasoning |
| Generate SQL from description | Maybe | Simple queries: yes; complex: no |
| Translate text | Yes (with caveats) | Simple translations work |
| Write tests from existing function | Maybe | If function signature is clear |

## Local Model Selection (Ollama)

```typescript
const MODELS = {
  'code-small': 'codellama:7b',      // code completion, 7B params
  'code-large': 'codellama:34b',     // better code, slower, more RAM
  'general': 'llama3.2:3b',         // fast general purpose
  'general-large': 'llama3.1:8b',   // better reasoning
  'reasoning': 'deepseek-r1:7b',    // math, logic, structured output
  'precise': 'qwen2.5-coder:7b',    // code-specific, accurate
}

function selectModel(task: TaskType): string {
  switch (task) {
    case 'code-generation': return MODELS['precise']
    case 'content-writing': return MODELS['general-large']
    case 'data-transformation': return MODELS['reasoning']
    case 'boilerplate': return MODELS['code-small']  // fastest
  }
}
```

## Model RAM Requirements

| Model Size | RAM Required |
|---|---|
| 3B | 4GB |
| 7B | 8GB |
| 13B | 16GB |
| 34B | 32GB (or VRAM) |

On a MacBook Pro M1 with 16GB: can run up to 7B-13B comfortably. 34B will be slow.

## Hybrid Routing in Batch Jobs

Route tasks to local or cloud based on complexity:
```typescript
interface TaskConfig {
  complexity: 'simple' | 'complex'
  quality: 'any' | 'high'
}

async function runTask(task: Task, config: TaskConfig): Promise<string> {
  if (config.complexity === 'simple' && config.quality === 'any') {
    // Use local Ollama
    return await ollamaGenerate(task.prompt, MODELS['code-small'])
  }
  
  if (config.quality === 'high') {
    // Use Sonnet for high quality
    return await claudeGenerate(task.prompt, 'claude-sonnet-4-6')
  }
  
  // Default: Haiku (fast cloud)
  return await claudeGenerate(task.prompt, 'claude-haiku-4-5')
}
```

## Fallback Chain

When local model fails or produces low-quality output, fall back to cloud:
```typescript
async function generateWithFallback(prompt: string): Promise<string> {
  // Try local first
  try {
    const localResult = await ollamaGenerate(prompt, 'llama3.1:8b')
    const quality = assessQuality(localResult)
    if (quality >= 0.7) return localResult
  } catch {
    // Ollama not running or out of memory
  }
  
  // Fall back to Haiku
  console.log('Local model fallback → Haiku')
  return await claudeGenerate(prompt, 'claude-haiku-4-5')
}
```

## Context Limit Comparison

| Model | Context Window | Practical Limit for Quality |
|---|---|---|
| Llama 3.2 3B | 128k | ~4k tokens |
| Llama 3.1 8B | 128k | ~8k tokens |
| DeepSeek R1 7B | 64k | ~8k tokens |
| Claude Haiku 4.5 | 200k | 100k+ tokens |
| Claude Sonnet 4.6 | 200k | 100k+ tokens |

Local models technically support large contexts but quality degrades significantly past 8-16k tokens. Keep prompts and context concise for local models.
