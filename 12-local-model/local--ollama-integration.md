# Ollama Integration for Local Inference

## What Ollama Provides

Ollama is a local model server that runs LLMs locally via a REST API similar to OpenAI's. It handles model downloading, quantization, and serving.

## Installation

```bash
# macOS
brew install ollama
ollama serve  # starts the server on localhost:11434

# Pull models
ollama pull llama3.1:8b         # 4.7GB — fast, general purpose
ollama pull deepseek-coder:6.7b  # 3.8GB — code-focused
ollama pull qwen2.5:7b           # 4.4GB — strong multilingual
ollama pull phi3:medium          # 7.9GB — Microsoft, very capable for size

# List downloaded models
ollama list
```

## REST API

Ollama exposes OpenAI-compatible endpoints AND its own API:

```typescript
// Option 1: OpenAI client pointing to Ollama
import OpenAI from 'openai'

const client = new OpenAI({
  baseURL: 'http://localhost:11434/v1',
  apiKey: 'ollama',  // required by client but ignored by Ollama
})

const response = await client.chat.completions.create({
  model: 'llama3.1:8b',
  messages: [{ role: 'user', content: 'Hello!' }],
})

// Option 2: Ollama native API (more options)
const response = await fetch('http://localhost:11434/api/chat', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    model: 'llama3.1:8b',
    messages: [{ role: 'user', content: 'Hello!' }],
    stream: false,
    options: {
      temperature: 0.7,
      num_predict: 1024,
    },
  }),
})
const data = await response.json()
const text = data.message.content
```

## Streaming with Ollama

```typescript
async function streamOllama(prompt: string, onChunk: (text: string) => void): Promise<void> {
  const response = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'llama3.1:8b',
      prompt,
      stream: true,
    }),
  })

  const reader = response.body!.getReader()
  const decoder = new TextDecoder()

  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    
    const lines = decoder.decode(value).split('\n').filter(Boolean)
    for (const line of lines) {
      const json = JSON.parse(line)
      if (json.response) onChunk(json.response)
      if (json.done) return
    }
  }
}
```

## Embedding with Ollama

```typescript
async function generateEmbedding(text: string): Promise<number[]> {
  const response = await fetch('http://localhost:11434/api/embeddings', {
    method: 'POST',
    body: JSON.stringify({
      model: 'nomic-embed-text',  // ollama pull nomic-embed-text
      prompt: text,
    }),
  })
  const data = await response.json()
  return data.embedding  // float32 array
}
```

## Model Context for Overnight Jobs

For batch jobs, create a wrapper that auto-retries and validates:

```typescript
// lib/local-model.ts
export async function generateWithOllama(
  prompt: string,
  model = 'llama3.1:8b',
  options: Record<string, unknown> = {}
): Promise<string | null> {
  try {
    const response = await fetch('http://localhost:11434/api/generate', {
      method: 'POST',
      body: JSON.stringify({
        model,
        prompt,
        stream: false,
        options: { temperature: 0.3, ...options },
      }),
    })
    
    if (!response.ok) throw new Error(`HTTP ${response.status}`)
    
    const data = await response.json()
    return data.response ?? null
  } catch (err) {
    console.error(`Ollama error: ${(err as Error).message}`)
    return null
  }
}
```

## Routing Between Local and Cloud

Use local models for cost efficiency, cloud for quality-sensitive tasks:

```typescript
type ModelTier = 'local-fast' | 'local-quality' | 'cloud-balanced' | 'cloud-best'

const MODEL_MAP: Record<ModelTier, { provider: 'ollama' | 'anthropic'; model: string }> = {
  'local-fast': { provider: 'ollama', model: 'phi3:medium' },
  'local-quality': { provider: 'ollama', model: 'llama3.1:8b' },
  'cloud-balanced': { provider: 'anthropic', model: 'claude-haiku-4-5' },
  'cloud-best': { provider: 'anthropic', model: 'claude-sonnet-4-6' },
}

async function generate(prompt: string, tier: ModelTier): Promise<string> {
  const { provider, model } = MODEL_MAP[tier]
  
  if (provider === 'ollama') {
    const result = await generateWithOllama(prompt, model)
    return result ?? ''
  }
  
  const client = new Anthropic()
  const msg = await client.messages.create({
    model,
    max_tokens: 1024,
    messages: [{ role: 'user', content: prompt }],
  })
  return msg.content[0].type === 'text' ? msg.content[0].text : ''
}
```

## Checking if Ollama is Running

```typescript
async function isOllamaRunning(): Promise<boolean> {
  try {
    const response = await fetch('http://localhost:11434/api/tags', { signal: AbortSignal.timeout(2000) })
    return response.ok
  } catch {
    return false
  }
}
```
