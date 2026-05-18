# Agent Context Management

## The Context Budget Problem

Every agent invocation has a context window limit. For complex tasks, the agent must manage what information it keeps in context vs. what it reads on demand.

Strategies:
1. **Front-load** critical context at the start
2. **Lazy-load** supporting details when needed
3. **Summarize** completed work to free space
4. **Off-load** details to files (progress tracking, results)

## What Belongs in Context

High value (always load):
- The goal and constraints
- The schema/types being worked with
- The last N results if there's a pattern to maintain
- Error context from recent failures

Low value (load on demand):
- Full file contents (load when editing, not before)
- Historical records (search when needed)
- Full documentation (load the specific section needed)
- Past completed tasks (only load if debugging)

## Token Budget Awareness

Load context files proportionally to how much of the window they use:

```typescript
// Context loading strategy for local models (small context):
// TOKEN_BUDGET = 3000 total

// Priority 1 (always load — ~500 tokens): task definition, goal
// Priority 2 (load if relevant — ~1000 tokens): stack bundle for the relevant tech
// Priority 3 (load if space — ~1000 tokens): specific pattern or example
// Reserve 500 tokens for the actual prompt

// For cloud models (200k window): much less constraint
// Load everything that might be relevant
```

## Progressive Context Loading

For complex tasks, load context in stages:

```typescript
// Stage 1: Load task specification (small, always needed)
const task = loadTaskSpec(taskId)

// Stage 2: Load relevant stack bundle based on task type:
let bundlePath: string
if (task.involves('supabase')) bundlePath = 'bundle--jrs-auto-repair-context.md'
if (task.involves('cloudflare')) bundlePath = 'bundle--cloudflare-workers-feature.md'
const bundle = fs.readFileSync(`knowledge-base/13-stack-bundles/${bundlePath}`, 'utf-8')

// Stage 3: Load specific pattern only if needed:
if (task.type === 'form') {
  const pattern = fs.readFileSync('knowledge-base/05-patterns/patterns--form-with-server-action.md', 'utf-8')
}
```

## The Research-Then-Act Split

Never mix research and action phases within a single agent invocation. Research produces information; action produces changes. Confusing them leads to acting on incomplete research.

```
Phase 1 — Research agent:
  - Reads relevant files
  - Summarizes what exists
  - Identifies what needs to change
  - Returns a plan

Phase 2 — Action agent (uses Phase 1 output):
  - Receives the plan from Phase 1
  - Makes targeted changes
  - Verifies results
  - Does NOT re-research
```

## Long-Running Task Context

For tasks taking many hours (overnight batch), the agent can't keep everything in memory. Use files as external memory:

```typescript
interface AgentMemory {
  goal: string
  completedTasks: string[]
  currentTask: string | null
  discoveredConstraints: string[]  // things found during research
  pendingWork: string[]
  notes: string  // anything the agent wants to remember
}

// Write to disk after every phase:
fs.writeFileSync('/tmp/agent-memory.json', JSON.stringify(memory, null, 2))

// Restore on resume:
const memory: AgentMemory = fs.existsSync('/tmp/agent-memory.json')
  ? JSON.parse(fs.readFileSync('/tmp/agent-memory.json', 'utf-8'))
  : { goal: process.argv[2], completedTasks: [], ... }
```

## Context Window Exhaustion Recovery

When an agent is running out of context window:

1. Summarize what's been done into a compact summary
2. Write the summary to a file
3. Start a fresh invocation with only the summary + remaining task

```typescript
// The "handoff" summary format:
const handoff = `
# Task Handoff

## Completed
${completed.map(t => `- ${t}`).join('\n')}

## Remaining  
${remaining.map(t => `- ${t}`).join('\n')}

## Key Findings
${findings.join('\n')}

## Next Action
${nextAction}
`

fs.writeFileSync('/tmp/task-handoff.md', handoff)
// Re-invoke with: "Continue from /tmp/task-handoff.md"
```

## What Not to Keep in Context

- Full file contents when only a specific function is relevant
- Complete test suites when only one test is failing
- Entire chat history when summarized earlier turns would suffice
- Duplicate information (don't load the same data twice)
- Tangentially related files "just in case"
