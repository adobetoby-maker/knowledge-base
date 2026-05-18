# Plugin: OpenAI SDK (Node.js)

## What It Is

The `openai` npm package for accessing OpenAI's API: GPT-4o, GPT-4.1, embedding models, DALL-E, Whisper. Use when: OpenAI-specific features are needed, comparing models, or the project is not exclusively Anthropic.

## Installation

```bash
npm install openai
```

## Basic Chat Completion

```ts
import OpenAI from 'openai'

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY })

const response = await openai.chat.completions.create({
  model: 'gpt-4o',
  messages: [
    { role: 'system', content: 'You are a helpful assistant.' },
    { role: 'user', content: 'What is the capital of France?' },
  ],
  max_tokens: 256,
  temperature: 0.7,
})

const text = response.choices[0].message.content
```

## Streaming

```ts
const stream = await openai.chat.completions.create({
  model: 'gpt-4o',
  messages: [{ role: 'user', content: prompt }],
  stream: true,
})

for await (const chunk of stream) {
  const delta = chunk.choices[0]?.delta?.content ?? ''
  process.stdout.write(delta)
}
```

## Embeddings

```ts
const response = await openai.embeddings.create({
  model: 'text-embedding-3-small',  // 1536 dimensions, cheap
  input: texts,  // string or string[]
})

const vectors = response.data.map((d) => d.embedding)
```

`text-embedding-3-small` for cost efficiency, `text-embedding-3-large` (3072 dims) for precision. Used for semantic search, RAG pipelines, similarity comparisons.

## Function Calling (Tool Use)

```ts
const tools: OpenAI.Chat.Completions.ChatCompletionTool[] = [
  {
    type: 'function',
    function: {
      name: 'get_invoice',
      description: 'Get invoice details by ID',
      parameters: {
        type: 'object',
        properties: {
          invoice_id: { type: 'string', description: 'Invoice UUID' },
        },
        required: ['invoice_id'],
      },
    },
  },
]

const response = await openai.chat.completions.create({
  model: 'gpt-4o',
  messages,
  tools,
  tool_choice: 'auto',
})

const toolCall = response.choices[0].message.tool_calls?.[0]
if (toolCall) {
  const args = JSON.parse(toolCall.function.arguments)
  const result = await getInvoice(args.invoice_id)
  // Continue with tool result...
}
```

## JSON Mode

```ts
const response = await openai.chat.completions.create({
  model: 'gpt-4o',
  messages: [
    {
      role: 'system',
      content: 'Return valid JSON matching the provided schema.',
    },
    { role: 'user', content: prompt },
  ],
  response_format: { type: 'json_object' },  // Guarantees valid JSON
})

const data = JSON.parse(response.choices[0].message.content!)
```

Validate the parsed JSON with Zod even in JSON mode — the model may return valid JSON that doesn't match your expected schema.

## Image Analysis (Vision)

```ts
const response = await openai.chat.completions.create({
  model: 'gpt-4o',
  messages: [
    {
      role: 'user',
      content: [
        { type: 'text', text: 'What does this receipt show?' },
        {
          type: 'image_url',
          image_url: {
            url: `data:image/jpeg;base64,${base64Image}`,
            detail: 'low',  // 'low' | 'high' — low is 85 tokens, high is 170+ per tile
          },
        },
      ],
    },
  ],
  max_tokens: 512,
})
```

## Audio Transcription (Whisper)

```ts
import fs from 'fs'

const transcription = await openai.audio.transcriptions.create({
  file: fs.createReadStream('/path/to/audio.mp3'),
  model: 'whisper-1',
  language: 'en',  // Optional — auto-detects otherwise
  response_format: 'text',  // 'json' | 'text' | 'srt' | 'verbose_json' | 'vtt'
})

console.log(transcription)  // The transcribed text
```

## Error Handling

```ts
import { OpenAI } from 'openai'

try {
  const response = await openai.chat.completions.create({ /* ... */ })
} catch (err) {
  if (err instanceof OpenAI.APIError) {
    console.error(err.status)   // HTTP status
    console.error(err.name)     // 'BadRequestError', 'RateLimitError', etc.
    console.error(err.message)
  }
  throw err
}
```

Common errors:
- `RateLimitError` (429) — implement exponential backoff
- `InvalidRequestError` (400) — bad parameters
- `AuthenticationError` (401) — invalid API key
- `InsufficientQuotaError` — account billing issue

## Model Routing Decision

Use OpenAI when:
- Embeddings are needed at scale (cheaper than Anthropic for embeddings)
- Image generation (DALL-E)
- Audio transcription (Whisper)
- Comparing against Claude for quality benchmarking

Use Anthropic SDK (claude-* models) when:
- Long context (Claude handles 200k tokens)
- Complex reasoning, coding, or instruction following
- Anything in the existing stack (default choice)
