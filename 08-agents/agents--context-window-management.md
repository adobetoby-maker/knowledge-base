# Agent Pattern: Context Window Management

## Overview

Every LLM has a finite context window. Agents that blindly accumulate conversation history, tool results, and documents will eventually hit the limit — producing truncation errors, degraded reasoning, or sky-high costs. Context management is an explicit architectural concern.

## The Problem at Scale

```
Turn 1: System prompt (2,000 tokens)
Turn 2: User message + tool result (5,000 tokens)
Turn 3: Response + next tool call (3,000 tokens)
...
Turn 20: History alone exceeds 100K tokens
```

At 100K tokens in context: costs $0.30+ per turn (at typical pricing), response latency increases, and model reasoning quality degrades on long contexts.

## Strategy 1: Sliding Window

Keep only the N most recent turns, always keeping system prompt and first user message:

```ts
interface Message {
  role: 'system' | 'user' | 'assistant'
  content: string
}

function applyContextWindow(messages: Message[], maxTokens: number): Message[] {
  const systemMessages = messages.filter(m => m.role === 'system')
  const nonSystem = messages.filter(m => m.role !== 'system')
  
  // Estimate tokens (rough: 1 token ≈ 4 chars)
  const estimateTokens = (msgs: Message[]) => 
    msgs.reduce((sum, m) => sum + Math.ceil(m.content.length / 4), 0)
  
  // Keep removing oldest non-system messages until under budget
  let window = [...nonSystem]
  while (estimateTokens([...systemMessages, ...window]) > maxTokens && window.length > 2) {
    window = window.slice(2)  // Remove oldest user+assistant pair
  }
  
  return [...systemMessages, ...window]
}
```

Risk: agent loses context of earlier decisions. Mitigate with summaries (see below).

## Strategy 2: Progressive Summarization

When approaching the limit, summarize old turns before discarding them:

```ts
async function summarizeHistory(messages: Message[], llm: LLMClient): Promise<string> {
  const historyText = messages
    .map(m => `${m.role}: ${m.content}`)
    .join('\n')
  
  return await llm.complete({
    messages: [
      {
        role: 'user',
        content: `Summarize the following conversation history, preserving key decisions, 
findings, and current task state. Be concise but complete.\n\n${historyText}`,
      },
    ],
  })
}

async function manageContext(
  messages: Message[],
  llm: LLMClient,
  maxTokens = 50000,
): Promise<Message[]> {
  const estimated = estimateTokens(messages)
  
  if (estimated < maxTokens * 0.8) return messages
  
  // Take the oldest half of non-system messages and summarize
  const [systemMsgs, conversationMsgs] = partition(messages, m => m.role === 'system')
  const oldMsgs = conversationMsgs.slice(0, Math.floor(conversationMsgs.length / 2))
  const recentMsgs = conversationMsgs.slice(Math.floor(conversationMsgs.length / 2))
  
  const summary = await summarizeHistory(oldMsgs, llm)
  
  return [
    ...systemMsgs,
    { role: 'user', content: `[Previous context summary]\n${summary}` },
    ...recentMsgs,
  ]
}
```

## Strategy 3: Tool Result Truncation

Tool results (web search, code execution output, database queries) are often the biggest context consumers. Truncate them intelligently:

```ts
function truncateToolResult(result: string, maxTokens: number): string {
  const maxChars = maxTokens * 4  // Rough token estimate
  if (result.length <= maxChars) return result
  
  const keep = Math.floor(maxChars * 0.8)
  const truncated = result.slice(0, keep)
  
  return `${truncated}\n\n[... truncated ${result.length - keep} characters. Show more?]`
}

// For JSON results: summarize structure instead of full content
function summarizeJsonResult(obj: unknown, maxDepth = 2): unknown {
  if (typeof obj !== 'object' || obj === null) return obj
  if (Array.isArray(obj)) {
    if (obj.length <= 3) return obj.map(item => summarizeJsonResult(item, maxDepth - 1))
    return [
      ...obj.slice(0, 2).map(item => summarizeJsonResult(item, maxDepth - 1)),
      `... ${obj.length - 2} more items`,
    ]
  }
  if (maxDepth <= 0) return '[object]'
  return Object.fromEntries(
    Object.entries(obj).map(([k, v]) => [k, summarizeJsonResult(v, maxDepth - 1)])
  )
}
```

## Strategy 4: Selective Tool Result Storage

Don't put large results in the message history. Store them externally and reference them:

```ts
const toolResultStore = new Map<string, string>()

function storeToolResult(toolCallId: string, result: string): string {
  toolResultStore.set(toolCallId, result)
  
  // Return a reference instead of the full result
  const preview = result.slice(0, 500)
  return `[Result stored as ${toolCallId}. Preview: ${preview}... Use retrieve_result(${toolCallId}) to access full content]`
}

// Add retrieve_result as a tool the agent can call
```

## Token Counting (Accurate)

For accurate counting (not char/4 estimate), use the model's tokenizer:

```ts
// For OpenAI-compatible APIs
import { encoding_for_model } from 'tiktoken'

const enc = encoding_for_model('gpt-4')
const tokens = enc.encode(text).length
enc.free()
```

For Anthropic: use the token counting API endpoint or estimate conservatively at 1 token per 3 chars.

## Budget Per Component

Allocate tokens intentionally:

```
Total budget: 100,000 tokens
  System prompt: 2,000 (2%)
  Task description: 1,000 (1%)
  Working memory / current task: 5,000 (5%)
  Tool results (this turn): 10,000 (10%)
  Conversation history: 30,000 (30%)
  Document context: 40,000 (40%)
  Response buffer: 12,000 (12%)
```

Hard-limit each component. Reject or truncate when a component exceeds its budget.
