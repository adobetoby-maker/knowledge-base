# Agents: Context Injection at Session Start

## The Problem

Agents starting a new session have no memory of previous sessions. Without context injection, every session starts cold — the agent doesn't know the project structure, recent decisions, or where it left off. Context injection loads the relevant state before work begins.

## What to Inject

```ts
interface SessionContext {
  coreMemory: string          // Key decisions, project invariants (always inject)
  recentActivity: string      // What happened in the last 7 days (always inject)
  projectContext: string      // Project-specific CLAUDE.md / stack bundles
  pendingWork?: string        // Unfinished items from previous session
  btwnotes?: string           // /btw captured thoughts for this project
}
```

**Always inject (small, always relevant):**
- Core memories: architectural decisions, domain rules, "never do X"
- Recent work: what changed in the last session

**Conditionally inject (larger, context-dependent):**
- Project-specific documentation: only for the project being worked on
- Error history: recent failures for the relevant category

**Available on demand (too large to always inject):**
- Full knowledge base articles
- Historical conversations
- Complete code context

## Session Start Hook (jrs-auto-repair model)

```bash
# ~/.claude/bootstrap/session-start.sh
# Called automatically by ~/.claude/hooks.json on session start

echo "Loading session context..."

# 1. Sync memory from GitHub
cd ~/.claude/projects/-Users-drive/memory
git pull origin main --quiet 2>/dev/null || echo "⚠️ Offline — using cached"

# 2. Inject core context
cat ~/.claude/projects/-Users-drive/memory/core-memories.md
echo "---"
cat ~/.claude/projects/-Users-drive/memory/recent.md

# 3. Surface pending /btw notes
if command -v claude-flow &> /dev/null; then
  claude-flow memory search --namespace btw -q "$(date +%Y-%m)" 2>/dev/null | head -20
fi
```

## Building System Prompt Context

For agent spawning, construct system context programmatically:

```ts
async function buildAgentContext(options: {
  projectName: string
  taskType: 'code' | 'content' | 'analysis'
}): Promise<string> {
  const parts: string[] = []

  // 1. Core memories (always)
  const coreMemory = await fs.promises.readFile(
    path.join(MEMORY_PATH, 'core-memories.md'), 'utf-8'
  )
  parts.push('# Core Context\n' + coreMemory)

  // 2. Recent activity (always)
  const recent = await fs.promises.readFile(
    path.join(MEMORY_PATH, 'recent.md'), 'utf-8'
  )
  parts.push('# Recent Activity\n' + recent.slice(0, 3000))  // Cap at 3000 tokens

  // 3. Project-specific context
  const projectBundle = path.join(
    KB_PATH, '13-stack-bundles', `bundle--${options.projectName}-context.md`
  )
  if (await fileExists(projectBundle)) {
    const projectContext = await fs.promises.readFile(projectBundle, 'utf-8')
    parts.push('# Project Context\n' + projectContext)
  }

  // 4. Task-type bundles
  if (options.taskType === 'code') {
    const authBundle = await fs.promises.readFile(
      path.join(KB_PATH, '13-stack-bundles', 'bundle--supabase-auth-context.md'), 'utf-8'
    )
    parts.push('# Auth Patterns\n' + authBundle)
  }

  return parts.join('\n\n---\n\n')
}
```

## Context Size Budgeting

Reserve space in the context window for the actual work:

```ts
function buildContextWithBudget(sections: Array<{ name: string; content: string }>, maxTokens = 20000): string {
  const parts: string[] = []
  let usedTokens = 0

  for (const section of sections) {
    const tokens = estimateTokens(section.content)

    if (usedTokens + tokens > maxTokens) {
      // Truncate this section to fit
      const remaining = maxTokens - usedTokens
      const truncated = section.content.slice(0, remaining * 4)  // rough chars-to-tokens
      parts.push(`# ${section.name}\n${truncated}\n[...truncated]`)
      break
    }

    parts.push(`# ${section.name}\n${section.content}`)
    usedTokens += tokens
  }

  return parts.join('\n\n---\n\n')
}
```

## Injecting via System Message vs First User Message

**System message** (preferred for persistent context):
```ts
const messages: Anthropic.MessageParam[] = [
  { role: 'user', content: TASK_DESCRIPTION }
]

const response = await client.messages.create({
  model: 'claude-sonnet-4-6',
  system: systemContext,  // Injected here
  messages,
  max_tokens: 4096,
})
```

**First user message** (use when system message isn't available or for structured prompts):
```ts
const messages: Anthropic.MessageParam[] = [
  {
    role: 'user',
    content: `${systemContext}\n\n---\n\nTask: ${TASK_DESCRIPTION}`
  }
]
```

Injecting into the system message is more efficient — it's cached separately from the conversation turns.

## When to Skip Context Injection

For short mechanical tasks (rename files, string replacement), full context injection wastes tokens:

```ts
// Fast path: skip context for mechanical tasks
if (taskType === 'mechanical') {
  return await client.messages.create({
    model: 'claude-haiku-4-5',
    max_tokens: 1024,
    messages: [{ role: 'user', content: prompt }],
    // No system context — saves tokens for bulk tasks
  })
}
```
