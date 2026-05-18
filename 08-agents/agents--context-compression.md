# Agent: Context Compression

## Overview

Long conversations exhaust context windows. Context compression summarizes older turns to free up space while preserving the information needed to continue. The right approach depends on agent type: task-oriented agents need summaries of decisions made; conversational agents need key facts about the user; research agents need accumulated findings.

## When to Compress

```ts
interface ContextStats {
  totalTokens: number
  messageCount: number
  maxTokens: number
}

function shouldCompress(stats: ContextStats): boolean {
  const usedFraction = stats.totalTokens / stats.maxTokens
  return usedFraction > 0.7  // Compress when 70% full
}
```

Start compression before hitting the limit — compressing at 70% leaves headroom for the compression response itself.

## Compression Strategy: Sliding Window

Keep recent messages verbatim, compress older ones:

```ts
interface CompressedContext {
  summary: string           // Summary of compressed messages
  retainedMessages: Message[]  // Recent messages kept verbatim
  compressedUntil: number   // Index up to which was compressed
}

async function compressContext(
  messages: Message[],
  retainCount = 10  // Keep last N messages verbatim
): Promise<CompressedContext> {
  if (messages.length <= retainCount) {
    return {
      summary: '',
      retainedMessages: messages,
      compressedUntil: 0,
    }
  }

  const toCompress = messages.slice(0, messages.length - retainCount)
  const retained = messages.slice(messages.length - retainCount)

  const summary = await summarizeMessages(toCompress)

  return {
    summary,
    retainedMessages: retained,
    compressedUntil: messages.length - retainCount,
  }
}
```

## Summary Generation

```ts
async function summarizeMessages(messages: Message[]): Promise<string> {
  const conversation = messages
    .map(m => `${m.role.toUpperCase()}: ${m.content}`)
    .join('\n\n')

  const response = await llm.chat({
    messages: [
      {
        role: 'system',
        content: 'You are summarizing a conversation for context preservation. Capture: key decisions made, important facts learned, current task state, and any open questions. Be concise but complete.',
      },
      {
        role: 'user',
        content: `Summarize this conversation:\n\n${conversation}`,
      },
    ],
    maxTokens: 500,
  })

  return response.content
}
```

## Injecting Summary into New Context

```ts
function buildContextWithSummary(
  systemPrompt: string,
  compressed: CompressedContext,
  newMessage: string
): Message[] {
  const messages: Message[] = [
    {
      role: 'system',
      content: systemPrompt,
    },
  ]

  // Inject summary as a system message if present
  if (compressed.summary) {
    messages.push({
      role: 'system',
      content: `[CONTEXT SUMMARY - earlier conversation]\n${compressed.summary}`,
    })
  }

  // Add retained messages
  messages.push(...compressed.retainedMessages)

  // Add new user message
  messages.push({ role: 'user', content: newMessage })

  return messages
}
```

## Task-Specific Compression

For task agents, extract structured state instead of prose summary:

```ts
async function extractTaskState(messages: Message[]): Promise<TaskState> {
  const response = await llm.chat({
    messages: [
      {
        role: 'user',
        content: `Extract the current task state from this conversation as JSON:
{
  "goal": "what we're trying to accomplish",
  "completedSteps": ["step 1", "step 2"],
  "currentStep": "what we're doing now",
  "pendingSteps": ["remaining steps"],
  "keyDecisions": {"decision1": "rationale"},
  "knownIssues": ["any blockers or constraints"],
  "artifacts": ["files created, schemas designed, etc."]
}

Conversation:
${messages.map(m => `${m.role}: ${m.content.slice(0, 500)}`).join('\n\n')}`,
      },
    ],
    format: 'json',
  })

  return JSON.parse(response.content)
}
```

## Compression Checkpointing

```ts
// Persist compressed state to survive process restart
async function checkpoint(sessionId: string, state: CompressedContext): Promise<void> {
  await redis.set(
    `session:${sessionId}:context`,
    JSON.stringify(state),
    'EX',
    24 * 60 * 60  // 24h
  )
}

async function restoreContext(sessionId: string): Promise<CompressedContext | null> {
  const data = await redis.get(`session:${sessionId}:context`)
  return data ? JSON.parse(data) : null
}
```

## Key Rules

- Compress at 70% context usage — don't wait for the hard limit; the compression response itself needs room.
- Keep the last 10 messages verbatim — the model needs recent context to understand what just happened.
- Label the summary clearly (`[CONTEXT SUMMARY]`) — it helps the model understand the distinction between summary and real messages.
- For task agents, extract structured state (completed steps, current step, key decisions) instead of prose — structured state is more reliably used.
- Compression is lossy — important details in compressed messages may be lost. For high-stakes agents, also maintain a full log outside the context window.
