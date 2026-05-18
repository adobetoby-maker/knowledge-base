# Skill: vercel-ai-sdk-expert

**Trigger:** Building AI-powered features: chat interfaces, streaming responses, tool calling, structured output, AI-driven forms or automations.
**Invoke:** `/vercel-ai-sdk-expert`
**Returns:** Complete AI SDK patterns for streaming chat, tool use, structured generation, provider configuration, and rate limiting.

## When to Invoke
- Adding chat to a Next.js app
- Streaming AI responses instead of waiting for full response
- Using function calling / tool use with AI
- Generating structured JSON from an AI call
- Picking the right model for a task
- Handling AI errors and rate limits gracefully

## Quick Decision Guide
```
User-facing chat:       useChat() hook + streamText() on server
Background processing:  generateText() — no streaming needed
Structured output:      generateObject() with Zod schema
Function calling:       streamText() with tools: { ... }
```

## Core Pattern — Chat with Streaming
```typescript
// Route handler (server)
import { streamText } from 'ai'

export async function POST(req: Request) {
  const { messages } = await req.json()
  const result = streamText({
    model: 'anthropic/claude-haiku-4-5',
    system: 'You are a helpful assistant.',
    messages,
    maxTokens: 500
  })
  return result.toDataStreamResponse()
}

// Client component
'use client'
import { useChat } from '@ai-sdk/react'
const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat()
```

## Tool Use
```typescript
import { streamText, tool } from 'ai'
import { z } from 'zod'

streamText({
  model: 'anthropic/claude-sonnet-4-6',
  messages,
  tools: {
    checkInventory: tool({
      description: 'Check if a service slot is available',
      parameters: z.object({ date: z.string(), service: z.string() }),
      execute: async ({ date, service }) => checkAvailability(date, service)
    })
  },
  maxSteps: 5  // multi-turn tool use
})
```

## Structured Output
```typescript
import { generateObject } from 'ai'
import { z } from 'zod'

const { object } = await generateObject({
  model: 'anthropic/claude-haiku-4-5',
  schema: z.object({
    summary: z.string(),
    sentiment: z.enum(['positive', 'neutral', 'negative']),
    priority: z.number().min(1).max(5)
  }),
  prompt: `Analyze this review: "${reviewText}"`
})
```

## Model Selection
```
Haiku 4.5   — chat responses, classification, summaries (cheap + fast)
Sonnet 4.6  — complex reasoning, code gen, tool use (smart + moderate cost)
Opus 4.7    — highest stakes tasks only (expensive)
```

## What Skill Returns
Complete SDK patterns, provider configuration, streaming hooks, error handling, rate limiting, cost optimization, and multi-modal (image/audio) patterns.
