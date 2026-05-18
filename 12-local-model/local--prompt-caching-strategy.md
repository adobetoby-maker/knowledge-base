# Local Model: Prompt Caching Strategy

## What Prompt Caching Is

Prompt caching avoids re-encoding the same prefix on every call when you're running many requests with a shared context (system prompt, reference documents, examples).

For Anthropic's API: cache_control markers tell the API to cache everything up to that point. On cache hit, prefix encoding is skipped, and you're billed only for the new tokens.

For local models: there's no billing, but KV cache (key-value cache) inside the inference engine serves the same function. Pre-warming the KV cache means the model doesn't re-process a long system prompt on every request.

## When Caching Pays Off

Caching is worth setting up when:
- System prompt + context is > 1000 tokens
- You're making > 10 calls with the same prefix
- The prefix rarely changes (changing it invalidates the cache)

For short prompts (< 500 tokens) or single-shot tasks, caching overhead doesn't pay off.

## Anthropic API: cache_control

```typescript
// Mark the system prompt for caching:
const response = await anthropic.messages.create({
  model: 'claude-haiku-4-5',
  max_tokens: 1024,
  system: [
    {
      type: 'text',
      text: `You are an automotive service assistant for Jr.'s Auto Repair in Twin Falls, ID.
      
${LONG_BUSINESS_CONTEXT}  // 2000+ tokens of reference data`,
      cache_control: { type: 'ephemeral' },  // cache this prefix
    }
  ],
  messages: [
    { role: 'user', content: userQuestion }  // only this changes per request
  ],
})
```

On the first call: no cache hit, full encoding. On subsequent calls within the cache window (5 minutes): cache hit, prefix skipped.

## Batching for Cache Efficiency

Process multiple items back-to-back to maximize cache hits:

```typescript
// Inefficient: interleave different system prompts → no cache hits
for (const item of items) {
  await processWithContextA(item)
  await processWithContextB(item)
}

// Efficient: batch by system prompt → cache warm throughout batch
const contextAItems = items.filter(...)
const contextBItems = items.filter(...)

// Process all context-A items first:
for (const item of contextAItems) {
  await processWithContextA(item)  // cache hit after first call
}

// Then all context-B items:
for (const item of contextBItems) {
  await processWithContextB(item)  // cache hit after first call
}
```

## Ollama KV Cache Pre-warming

For local Ollama models, pre-warm the context by sending a dummy request with the full system prompt before the batch:

```typescript
async function prewarmContext(systemPrompt: string, model: string): Promise<void> {
  await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model,
      prompt: '',  // empty prompt — just loads the context
      system: systemPrompt,
      stream: false,
      options: { num_predict: 1 },  // generate 1 token, then stop
    }),
  })
  console.log('Context pre-warmed')
}

// Before batch:
await prewarmContext(SYSTEM_PROMPT, 'llama3.2')

// Now run batch with same system prompt — KV cache is warm:
for (const item of items) {
  await generateWithCachedContext(item, SYSTEM_PROMPT)
}
```

## Template Construction for Maximum Cache Hits

Put the stable part first, the variable part last:

```typescript
// System prompt structure for maximum caching:
const systemPrompt = [
  // STABLE (cached across all requests):
  'You are an expert automotive technician assistant.',
  `Business context: ${BUSINESS_INFO}`,          // never changes
  `Service categories: ${SERVICE_CATEGORIES}`,   // rarely changes
  '',
  // VARIABLE (not cached — append to user message instead):
  // Don't put customer-specific context in the system prompt!
].join('\n')

// Variable context goes in the user turn:
const userMessage = `
Customer context: ${customer.name}, ${customer.vehicleHistory}
Question: ${question}
`
```

## Measuring Cache Effectiveness

Anthropic API returns cache usage in the response:

```typescript
const response = await anthropic.messages.create(...)

console.log({
  inputTokens: response.usage.input_tokens,
  cacheCreationTokens: response.usage.cache_creation_input_tokens,  // first call: creates cache
  cacheReadTokens: response.usage.cache_read_input_tokens,          // subsequent: reads cache
})

// cache_read_input_tokens > 0 = cache hit
// cache_creation_input_tokens > 0 = cache miss (first time seeing this prefix)
```

Cache read tokens cost ~10% of normal input token pricing, so a 10:1 hit ratio pays for the caching overhead.
