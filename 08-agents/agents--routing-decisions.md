# Agent Routing Decisions

## What Routing Means

Routing = deciding which model, tool, or sub-agent handles a given task. The goal is to match task complexity to model capability while minimizing cost.

## Model Capability Tiers

| Model | Use for | Relative cost |
|---|---|---|
| Haiku 4.5 | File transforms, string replacements, curl calls, git commits, npm installs, renaming | ~1x |
| Sonnet 4.6 | TypeScript architecture, multi-file debugging, content writing, orchestration decisions | ~10x |
| Opus 4.7 | High-stakes product decisions, novel architecture, security analysis | ~100x |

Routing rule: if you could write the task as a one-line shell command, use Haiku. If it requires design judgment or cross-file reasoning, use Sonnet. If it's irreversible or high-stakes, use Opus.

## Input-Based Routing

Route based on what the task requires, not what it sounds like:

```typescript
type TaskCategory =
  | 'mechanical'    // string replace, file copy, rename — Haiku
  | 'analytical'    // understand then transform — Sonnet
  | 'creative'      // generate novel content — Sonnet
  | 'architectural' // cross-system design decisions — Opus

function routeTask(task: string): TaskCategory {
  const mechanicalPatterns = [
    /rename|move|copy|delete/i,
    /replace.*with/i,
    /install|update.*package/i,
    /git (add|commit|push)/i,
    /run.*test|run.*lint/i,
  ]
  
  if (mechanicalPatterns.some(p => p.test(task))) return 'mechanical'
  
  const architecturalPatterns = [
    /design|architect|system/i,
    /trade.off|choose between/i,
    /high.stakes|production|security/i,
  ]
  
  if (architecturalPatterns.some(p => p.test(task))) return 'architectural'
  
  return 'analytical'
}
```

## Fallback Chain

Try cheaper models first, escalate on failure:

```typescript
async function executeWithFallback(task: string): Promise<string> {
  const categories: TaskCategory[] = ['mechanical', 'analytical', 'architectural']
  const models = ['claude-haiku-4-5', 'claude-sonnet-4-6', 'claude-opus-4-7']
  
  const category = routeTask(task)
  const startIndex = categories.indexOf(category)
  
  for (let i = startIndex; i < models.length; i++) {
    try {
      return await callModel(models[i], task)
    } catch (error) {
      if (i === models.length - 1) throw error
      console.warn(`${models[i]} failed, escalating to ${models[i + 1]}`)
    }
  }
  
  throw new Error('All models failed')
}
```

## Tool Routing

Match tasks to the right tool:

| Task | Right tool | Wrong tool |
|---|---|---|
| Read a file at a known path | Read | Bash + cat |
| Edit a file | Edit | Write (for modifications) |
| Search for a symbol | Bash + grep | Agent + Explore |
| Broad codebase exploration | Agent (Explore) | Bash + find |
| Research + implementation | Agent (Plan then implement) | Single prompt |
| 3+ independent lookups | Multiple parallel tool calls | Sequential calls |

## Scope Detection for Agents

Route to a sub-agent when:
- The task requires > 5 tool calls to complete
- The task could succeed or fail independently without affecting the parent
- The task result will be used as input to a different task
- The task involves researching something and then acting on it

Keep in main context when:
- The task is 1-3 tool calls
- The result needs to influence the very next step in a tight loop
- State or context from recent turns is needed

## Routing by Data Volume

```typescript
function routeSearch(dataSize: number): 'client-side' | 'db-filter' | 'full-text' {
  if (dataSize < 500) return 'client-side'      // filter in memory
  if (dataSize < 50000) return 'db-filter'       // ILIKE
  return 'full-text'                              // tsvector + GIN index
}
```

Same principle applies to agents: small tasks stay in the orchestrator, large tasks get delegated.
