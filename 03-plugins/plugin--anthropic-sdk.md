# Anthropic SDK (AI Features)

## Where It's Used

- `jrs-auto-repair`: AI chatbot using `claude-haiku-4-5`
- `language-lens-elite`: tutor, speak, discussion, kana conversion using Claude Haiku
- `silver-creek-logistics`: AI-powered dispatch suggestions
- `manage-worker-bee`: blueprint wizard using Anthropic SDK

## Installation

```bash
npm install @anthropic-ai/sdk
```

## Basic Message (Non-Streaming)

```typescript
import Anthropic from '@anthropic-ai/sdk'

const client = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,  // server-side only — never NEXT_PUBLIC_
})

export async function generateResponse(prompt: string): Promise<string> {
  const message = await client.messages.create({
    model: 'claude-haiku-4-5',  // fast and cheap for most tasks
    max_tokens: 1024,
    messages: [{ role: 'user', content: prompt }],
  })

  if (message.content[0].type !== 'text') {
    throw new Error('Unexpected response type')
  }
  
  return message.content[0].text
}
```

## Streaming Response

Used in `language-lens-elite` for tutor/speak features — sends content as it generates:

```typescript
// Route Handler (Next.js)
export async function POST(req: NextRequest) {
  const { message } = await req.json()
  
  const stream = await client.messages.stream({
    model: 'claude-haiku-4-5',
    max_tokens: 1024,
    messages: [{ role: 'user', content: message }],
  })

  const readable = new ReadableStream({
    async start(controller) {
      for await (const chunk of stream) {
        if (chunk.type === 'content_block_delta' && chunk.delta.type === 'text_delta') {
          controller.enqueue(new TextEncoder().encode(chunk.delta.text))
        }
      }
      controller.close()
    },
  })

  return new Response(readable, {
    headers: { 'Content-Type': 'text/event-stream' },
  })
}
```

## Model Selection

| Model | Use Case | Cost |
|---|---|---|
| `claude-haiku-4-5` | High-volume, fast tasks (chatbot, content generation) | Lowest |
| `claude-sonnet-4-6` | Complex reasoning, code generation | Medium |
| `claude-opus-4-7` | High-stakes decisions, deep analysis | Highest |

For jrs-auto-repair chatbot: always use Haiku — it's fast enough for customer queries.
For manage-worker-bee blueprint wizard: Sonnet for better quality blueprints.

## System Prompts

```typescript
const message = await client.messages.create({
  model: 'claude-haiku-4-5',
  max_tokens: 1024,
  system: `You are a helpful assistant for Jr.'s Auto Repair, a local auto shop in Twin Falls, Idaho.
Answer questions about our services, hours, and location.
Business hours: Monday-Saturday 9AM-5PM.
Phone: (208) 595-2101.
Address: 417 Main Ave E, Twin Falls, ID.
If asked about pricing, say prices vary by vehicle and you'd be happy to give them a quote.
Keep responses concise and friendly.`,
  messages: [{ role: 'user', content: userMessage }],
})
```

## Conversation History

For multi-turn conversations, pass the full history:
```typescript
interface Message {
  role: 'user' | 'assistant'
  content: string
}

async function chat(history: Message[], newMessage: string): Promise<string> {
  const messages = [
    ...history,
    { role: 'user' as const, content: newMessage },
  ]
  
  const response = await client.messages.create({
    model: 'claude-haiku-4-5',
    max_tokens: 1024,
    messages,
  })
  
  return response.content[0].type === 'text' ? response.content[0].text : ''
}
```

## Error Handling

```typescript
import Anthropic from '@anthropic-ai/sdk'

try {
  const response = await client.messages.create(...)
} catch (error) {
  if (error instanceof Anthropic.APIError) {
    if (error.status === 429) {
      // Rate limited — retry with exponential backoff
    } else if (error.status === 400) {
      // Bad request — prompt too long, invalid model, etc.
    }
  }
  throw error
}
```

## Rate Limits

Anthropic rate limits by model tier. For batch jobs:
- Haiku: higher rate limits
- Sonnet/Opus: lower rate limits
- Add delays between batch requests: 1s between Haiku, 2s between Sonnet

See `batch--seo-article-generation.md` for batch job patterns.

## Never Expose the API Key

```typescript
// WRONG: client-side usage
// React component that calls Anthropic directly — API key exposed in browser

// CORRECT: always proxy through Route Handler or Server Action
// Client component → fetch('/api/chat') → Route Handler → Anthropic SDK
```

`ANTHROPIC_API_KEY` must NEVER be `NEXT_PUBLIC_ANTHROPIC_API_KEY`. Server-side only.
