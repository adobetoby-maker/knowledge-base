# Plugin/Skill: vercel-ai-sdk-expert

**What it provides:** Patterns for building AI features using Vercel AI SDK v6 — streaming chat, tool use, structured outputs, multi-step agents.
**Skill:** `/vercel-ai-sdk-expert`
**Also relevant:** `vercel:ai-architect` agent for system-level AI feature design.

## When to Use
- Adding a chat interface to any project
- Streaming AI responses to the browser
- Using tool calls (function calling) with AI
- Building multi-step AI workflows
- Integrating Anthropic/OpenAI/other providers

## Key 2026 Update — AI Gateway
On Vercel, use the AI Gateway by default:
```typescript
// OLD: provider-specific package
import { anthropic } from '@ai-sdk/anthropic'
const model = anthropic('claude-haiku-4-5')

// NEW: Vercel AI Gateway (unified, with observability + fallbacks)
import { createProviderRegistry } from 'ai'
const model = 'anthropic/claude-haiku-4-5'  // plain string through gateway
```

## Streaming Chat (App Router)
```typescript
// app/api/chat/route.ts
import { streamText } from 'ai'

export async function POST(req: Request) {
  const { messages } = await req.json()
  
  const result = streamText({
    model: 'anthropic/claude-haiku-4-5',
    messages,
    system: "You are a helpful assistant for Jr.'s Auto Repair in Twin Falls, ID."
  })
  
  return result.toDataStreamResponse()
}
```

```typescript
// components/Chat.tsx
'use client'
import { useChat } from '@ai-sdk/react'

export function Chat() {
  const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat({
    api: '/api/chat'
  })
  
  return (
    <div>
      {messages.map(m => (
        <div key={m.id} className={m.role === 'user' ? 'text-right' : 'text-left'}>
          {m.content}
        </div>
      ))}
      <form onSubmit={handleSubmit}>
        <input value={input} onChange={handleInputChange} placeholder="Ask a question..." />
        <button type="submit" disabled={isLoading}>Send</button>
      </form>
    </div>
  )
}
```

## Tool Use (Function Calling)
```typescript
import { streamText, tool } from 'ai'
import { z } from 'zod'

const result = streamText({
  model: 'anthropic/claude-sonnet-4-6',
  messages,
  tools: {
    getAppointments: tool({
      description: 'Get available appointment times at the shop',
      parameters: z.object({
        date: z.string().describe('Date in YYYY-MM-DD format'),
        service: z.string().describe('Type of service needed')
      }),
      execute: async ({ date, service }) => {
        return await getAvailableSlots(date, service)
      }
    })
  },
  maxSteps: 5  // allows multi-turn tool use
})
```

## Structured Output
```typescript
import { generateObject } from 'ai'
import { z } from 'zod'

const { object } = await generateObject({
  model: 'anthropic/claude-haiku-4-5',
  schema: z.object({
    sentiment: z.enum(['positive', 'neutral', 'negative']),
    summary: z.string(),
    urgency: z.number().min(1).max(5)
  }),
  prompt: `Analyze this customer feedback: "${feedback}"`
})
// object is fully typed: { sentiment: 'positive', summary: '...', urgency: 3 }
```

## Rate Limiting / Cost Control
```typescript
// Limit responses to reasonable length
const result = streamText({
  model: 'anthropic/claude-haiku-4-5',
  messages,
  maxTokens: 500,  // prevent runaway responses
  temperature: 0.7
})
```

## Which Model for Which AI Task
```
Chat/Q&A answering:      claude-haiku-4-5    (fast, cheap)
Complex reasoning:        claude-sonnet-4-6   (smart, moderate cost)
Code generation:          claude-sonnet-4-6   (best quality for code)
Content classification:   claude-haiku-4-5    (simple task = cheap model)
```
