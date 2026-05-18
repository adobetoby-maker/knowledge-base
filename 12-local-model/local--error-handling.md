# Local Model: Error Handling and Resilience

## The Problem

Local models (Ollama) fail differently from API models. Ollama might crash mid-generation, return partial JSON, time out on long prompts, or produce garbled output when VRAM is exhausted. Overnight batch scripts must handle these failures gracefully and resume from where they left off.

## Ollama-Specific Errors

```ts
class OllamaError extends Error {
  constructor(
    message: string,
    public code: 'TIMEOUT' | 'PARTIAL_RESPONSE' | 'MODEL_NOT_FOUND' | 'OOM' | 'CONNECTION_REFUSED'
  ) {
    super(message)
  }
}

async function callOllama(
  model: string,
  prompt: string,
  timeoutMs = 120_000  // 2 minutes max
): Promise<string> {
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs)

  try {
    const res = await fetch('http://localhost:11434/api/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model, prompt, stream: false }),
      signal: controller.signal,
    })

    clearTimeout(timeoutId)

    if (res.status === 404) {
      throw new OllamaError(`Model not found: ${model}`, 'MODEL_NOT_FOUND')
    }

    if (!res.ok) {
      const text = await res.text()
      if (text.includes('out of memory')) throw new OllamaError('VRAM exhausted', 'OOM')
      throw new OllamaError(`Ollama error ${res.status}: ${text}`, 'PARTIAL_RESPONSE')
    }

    const data = await res.json()
    if (!data.response) throw new OllamaError('Empty response from Ollama', 'PARTIAL_RESPONSE')

    return data.response

  } catch (err) {
    clearTimeout(timeoutId)

    if (err instanceof OllamaError) throw err

    if (err instanceof Error) {
      if (err.name === 'AbortError') throw new OllamaError('Request timed out', 'TIMEOUT')
      if (err.message.includes('ECONNREFUSED')) {
        throw new OllamaError('Ollama is not running (connection refused)', 'CONNECTION_REFUSED')
      }
    }

    throw err
  }
}
```

## Retry Strategy

Different errors need different retry behavior:

```ts
async function callOllamaWithRetry(
  model: string,
  prompt: string,
  maxRetries = 3,
): Promise<string> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await callOllama(model, prompt)
    } catch (err) {
      if (!(err instanceof OllamaError)) throw err  // Unknown error — don't retry

      switch (err.code) {
        case 'MODEL_NOT_FOUND':
          // Pull the model and retry once
          if (attempt === 0) {
            console.log(`Pulling model ${model}...`)
            await pullOllamaModel(model)
            continue
          }
          throw err  // Still failing after pull

        case 'TIMEOUT':
          if (attempt < maxRetries - 1) {
            // Truncate prompt and retry with shorter input
            const truncated = prompt.slice(0, Math.floor(prompt.length * 0.7))
            console.warn(`Timeout: retrying with ${Math.round(truncated.length / prompt.length * 100)}% of prompt`)
            prompt = truncated
            continue
          }
          throw err

        case 'OOM':
          // VRAM exhausted — wait for memory to free and retry
          if (attempt < maxRetries - 1) {
            console.warn('VRAM OOM: waiting 30s before retry')
            await new Promise(r => setTimeout(r, 30_000))
            continue
          }
          throw err

        case 'CONNECTION_REFUSED':
          // Ollama crashed — attempt restart
          if (attempt === 0) {
            await restartOllama()
            await new Promise(r => setTimeout(r, 5000))  // Wait for startup
            continue
          }
          throw err

        default:
          if (attempt < maxRetries - 1) {
            await new Promise(r => setTimeout(r, 2000 * (attempt + 1))  )  // Exponential backoff
            continue
          }
          throw err
      }
    }
  }
  throw new Error('Exhausted retries')
}
```

## Ollama Health Check

Run before starting a batch to catch problems early:

```ts
async function checkOllamaHealth(model: string): Promise<void> {
  // 1. Check Ollama is running
  try {
    const res = await fetch('http://localhost:11434/api/tags', { signal: AbortSignal.timeout(5000) })
    if (!res.ok) throw new Error(`Ollama health check failed: ${res.status}`)
  } catch (err) {
    throw new Error('Ollama is not running. Start with: ollama serve')
  }

  // 2. Check model is available
  const res = await fetch('http://localhost:11434/api/tags')
  const { models } = await res.json()
  const available = models.map((m: { name: string }) => m.name)

  if (!available.includes(model)) {
    console.log(`Model ${model} not found. Available: ${available.join(', ')}`)
    console.log(`Pulling ${model}...`)
    await pullOllamaModel(model)
  }

  // 3. Test generation
  const test = await callOllama(model, 'Reply with "OK"', 10_000)
  if (!test.trim()) throw new Error('Model returned empty test response')

  console.log(`✓ Ollama health check passed for ${model}`)
}
```

## Progress File for Resumability

```ts
interface BatchProgress {
  totalItems: number
  completedItems: number
  failedItems: string[]
  startedAt: string
  lastUpdatedAt: string
}

const PROGRESS_FILE = '/tmp/batch-progress.json'

function loadProgress(): BatchProgress | null {
  if (!fs.existsSync(PROGRESS_FILE)) return null
  return JSON.parse(fs.readFileSync(PROGRESS_FILE, 'utf-8'))
}

function saveProgress(progress: BatchProgress) {
  fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2))
}

// Usage in batch loop:
const progress = loadProgress() ?? { totalItems: items.length, completedItems: 0, failedItems: [], startedAt: new Date().toISOString(), lastUpdatedAt: '' }
const startIndex = progress.completedItems  // Resume from checkpoint

for (let i = startIndex; i < items.length; i++) {
  try {
    await processItem(items[i])
    progress.completedItems++
  } catch (err) {
    progress.failedItems.push(items[i].id)
  }
  progress.lastUpdatedAt = new Date().toISOString()
  if (i % 10 === 0) saveProgress(progress)  // Checkpoint every 10 items
}
```

## Memory Management for Long Batches

Local models hold the model weights in VRAM. Long sessions can accumulate fragmentation:

```bash
# Check VRAM usage before starting
nvidia-smi --query-gpu=memory.used,memory.free --format=csv

# If VRAM is fragmented after many requests, restart Ollama to free it
ollama stop llama3.2:8b
ollama serve &  # Restart the daemon
sleep 5
ollama pull llama3.2:8b  # Reload model weights
```

For batch scripts running overnight, add a periodic restart every 500 items to prevent VRAM fragmentation from accumulating.
