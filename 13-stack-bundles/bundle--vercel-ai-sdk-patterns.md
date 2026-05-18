# Stack Bundle: Vercel AI SDK — Complete Patterns

## Package Setup

```bash
npm install ai @ai-sdk/anthropic
```

## Model Configuration

```typescript
import { anthropic } from '@ai-sdk/anthropic'

// Default models for each use case:
const CHAT_MODEL = anthropic('claude-haiku-4-5')         // fast, cheap
const REASONING_MODEL = anthropic('claude-sonnet-4-6')   // smart, moderate
const ANALYSIS_MODEL = anthropic('claude-sonnet-4-6')    // structured output
```

## Pattern 1: Streaming Chat (User-Facing)

```typescript
// Route handler: app/api/chat/route.ts
import { streamText } from 'ai'
import { anthropic } from '@ai-sdk/anthropic'

export async function POST(req: Request) {
  const { messages } = await req.json()
  
  const result = streamText({
    model: anthropic('claude-haiku-4-5'),
    system: 'You are a helpful assistant for Jr\'s Auto Repair in Twin Falls, ID.',
    messages,
    maxTokens: 500,
  })
  
  return result.toDataStreamResponse()
}

// Client component: components/ChatWidget.tsx
'use client'
import { useChat } from '@ai-sdk/react'

export function ChatWidget() {
  const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat({
    api: '/api/chat',
  })
  
  return (
    <div>
      <div>
        {messages.map(m => <div key={m.id}><b>{m.role}:</b> {m.content}</div>)}
      </div>
      <form onSubmit={handleSubmit}>
        <input value={input} onChange={handleInputChange} />
        <button type="submit" disabled={isLoading}>Send</button>
      </form>
    </div>
  )
}
```

## Pattern 2: Structured Output (generateObject)

```typescript
import { generateObject } from 'ai'
import { anthropic } from '@ai-sdk/anthropic'
import { z } from 'zod'

export async function analyzeReview(reviewText: string) {
  const { object } = await generateObject({
    model: anthropic('claude-haiku-4-5'),
    schema: z.object({
      sentiment: z.enum(['positive', 'neutral', 'negative']),
      summary: z.string().max(100),
      responseRequired: z.boolean(),
      urgency: z.number().min(1).max(5),
    }),
    prompt: `Analyze this customer review: "${reviewText}"`,
    temperature: 0,  // deterministic for classification
  })
  
  return object  // fully typed by Zod schema
}
```

## Pattern 3: Tool Use (Function Calling)

```typescript
import { streamText, tool } from 'ai'
import { z } from 'zod'

export async function POST(req: Request) {
  const { messages } = await req.json()
  
  const result = streamText({
    model: anthropic('claude-sonnet-4-6'),
    system: 'You are a scheduling assistant for an auto repair shop.',
    messages,
    tools: {
      checkAvailability: tool({
        description: 'Check if a service slot is available on a given date',
        parameters: z.object({
          date: z.string().describe('Date in YYYY-MM-DD format'),
          serviceType: z.string().describe('Type of service requested'),
        }),
        execute: async ({ date, serviceType }) => {
          const slots = await getAvailableSlots(date, serviceType)
          return { available: slots.length > 0, slots }
        },
      }),
      bookAppointment: tool({
        description: 'Book an appointment for a customer',
        parameters: z.object({
          date: z.string(),
          time: z.string(),
          customerName: z.string(),
          phone: z.string(),
          service: z.string(),
        }),
        execute: async (params) => {
          const booking = await createBooking(params)
          return { success: true, confirmationId: booking.id }
        },
      }),
    },
    maxSteps: 5,  // allow multi-step tool use
  })
  
  return result.toDataStreamResponse()
}
```

## Pattern 4: Background Processing (generateText)

```typescript
import { generateText } from 'ai'

// For non-streaming, background processing
async function generateArticle(topic: string, keywords: string[]): Promise<string> {
  const { text } = await generateText({
    model: anthropic('claude-haiku-4-5'),
    prompt: `Write a 700-word SEO article about "${topic}". Include keywords: ${keywords.join(', ')}.`,
    maxTokens: 1000,
    temperature: 0.7,
  })
  
  return text
}
```

## Error Handling

```typescript
import { APIError } from 'ai'

try {
  const { text } = await generateText({ model, prompt })
} catch (error) {
  if (error instanceof APIError) {
    if (error.status === 429) {
      // Rate limited — retry after delay
      await new Promise(r => setTimeout(r, 60000))
      // retry...
    }
    if (error.status === 400) {
      // Bad request — prompt too long or content policy
    }
  }
  throw error
}
```

## TanStack Start Server Function Pattern (language-lens-elite)

```typescript
// src/routes/api.tutor.ts
import { createServerFn } from '@tanstack/start'
import { anthropic } from '@ai-sdk/anthropic'
import { generateText } from 'ai'
import { z } from 'zod'

export const tutorFn = createServerFn({ method: 'POST' })
  .validator(z.object({ question: z.string(), language: z.string() }))
  .handler(async ({ data }) => {
    const { text } = await generateText({
      model: anthropic('claude-haiku-4-5'),
      system: `You are a ${data.language} language tutor.`,
      prompt: data.question,
    })
    return { answer: text }
  })
```

## Environment Variables

```
ANTHROPIC_API_KEY    ← required for all Anthropic models
```

The Vercel AI SDK reads `ANTHROPIC_API_KEY` automatically from the environment.
