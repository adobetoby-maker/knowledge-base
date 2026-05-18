# Agents: Streaming Output Patterns

## What This Solves

Streaming makes AI responses appear immediately instead of waiting for the full completion. For long responses (code generation, reports, article writing), streaming dramatically improves perceived performance. The challenge is handling the stream correctly on both server and client.

## Vercel AI SDK Streaming (Recommended for Next.js)

```ts
// app/api/chat/route.ts
import { streamText } from 'ai'
import { anthropic } from '@ai-sdk/anthropic'

export async function POST(request: Request) {
  const { messages } = await request.json()

  const result = streamText({
    model: anthropic('claude-sonnet-4-6'),
    messages,
    system: 'You are a helpful assistant.',
  })

  return result.toDataStreamResponse()
}
```

Client-side:
```tsx
'use client'
import { useChat } from 'ai/react'

export function ChatInterface() {
  const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat()

  return (
    <div>
      <div className="space-y-4">
        {messages.map(msg => (
          <div key={msg.id} className={msg.role === 'user' ? 'text-right' : ''}>
            <p className="text-sm">{msg.content}</p>
          </div>
        ))}
        {isLoading && <LoadingDots />}
      </div>
      <form onSubmit={handleSubmit}>
        <input value={input} onChange={handleInputChange} placeholder="Ask..." />
        <button type="submit">Send</button>
      </form>
    </div>
  )
}
```

## Raw Anthropic SDK Streaming

For non-chat streaming (document generation, code writing):

```ts
// Server: returns a ReadableStream
export async function POST(request: Request) {
  const { prompt } = await request.json()

  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder()

      const anthropicStream = await client.messages.stream({
        model: 'claude-sonnet-4-6',
        max_tokens: 4096,
        messages: [{ role: 'user', content: prompt }],
      })

      for await (const chunk of anthropicStream) {
        if (
          chunk.type === 'content_block_delta' &&
          chunk.delta.type === 'text_delta'
        ) {
          controller.enqueue(encoder.encode(chunk.delta.text))
        }
      }

      controller.close()
    },
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Transfer-Encoding': 'chunked',
      'X-Content-Type-Options': 'nosniff',
    },
  })
}
```

Client-side reader:
```tsx
const [text, setText] = useState('')

async function generate(prompt: string) {
  const response = await fetch('/api/generate', {
    method: 'POST',
    body: JSON.stringify({ prompt }),
    headers: { 'Content-Type': 'application/json' },
  })

  const reader = response.body!.getReader()
  const decoder = new TextDecoder()

  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    setText(prev => prev + decoder.decode(value, { stream: true }))
  }
}
```

## StreamingText Component

For a typing effect with cursor:

```tsx
'use client'
interface StreamingTextProps {
  text: string
  isStreaming: boolean
}

export function StreamingText({ text, isStreaming }: StreamingTextProps) {
  return (
    <div className="prose max-w-none">
      <span className="whitespace-pre-wrap">{text}</span>
      {isStreaming && (
        <span className="inline-block w-0.5 h-4 bg-foreground animate-pulse ml-0.5 align-middle" />
      )}
    </div>
  )
}
```

## Streaming with Tool Calls

When streaming responses that also use tools, handle the interleaved events:

```ts
const stream = client.messages.stream({
  model: 'claude-sonnet-4-6',
  max_tokens: 4096,
  tools,
  messages,
})

let currentToolUseBlock: Anthropic.ToolUseBlock | null = null

for await (const event of stream) {
  if (event.type === 'content_block_start') {
    if (event.content_block.type === 'tool_use') {
      currentToolUseBlock = event.content_block
    }
  }

  if (event.type === 'content_block_delta') {
    if (event.delta.type === 'text_delta') {
      process.stdout.write(event.delta.text)  // Stream text to output
    }
    if (event.delta.type === 'input_json_delta') {
      // Tool input is being accumulated — don't execute until content_block_stop
    }
  }

  if (event.type === 'content_block_stop' && currentToolUseBlock) {
    // Tool input is now complete — execute it
    const result = await executeToolSafely(currentToolUseBlock.name, currentToolUseBlock.input)
    currentToolUseBlock = null
    // Continue the conversation with the tool result
  }
}
```

## Aborting a Stream

```tsx
const abortController = useRef<AbortController | null>(null)

const generate = async () => {
  abortController.current = new AbortController()

  try {
    const response = await fetch('/api/generate', {
      signal: abortController.current.signal,
      // ...
    })
    // ... read stream
  } catch (err) {
    if (err instanceof Error && err.name === 'AbortError') return  // User cancelled
    throw err
  }
}

const stop = () => abortController.current?.abort()
```

## Edge Runtime for Streaming

Vercel's Edge Runtime is required for streaming responses — Node.js runtime doesn't support streaming in the same way:

```ts
export const runtime = 'edge'  // In the route file

// Edge runtime limitations:
// - No Node.js built-ins (fs, path, etc.)
// - No npm packages that depend on Node.js APIs
// - Max 2MB bundle
```
