# Pattern: AI Summarize Button

## Overview
A "Summarize" button on long content must stream the response to feel fast — a 3-second blank wait loses users. The API key must never touch the client, so all calls route through a server-side endpoint. Without a cost guard, users can trigger expensive calls on 10-character inputs.

## Implementation

```typescript
// app/api/summarize/route.ts — server-side only
import { NextRequest } from 'next/server'

export async function POST(req: NextRequest) {
  const { content } = await req.json()

  // Cost guard: refuse to summarize short content
  if (!content || content.length < 500) {
    return Response.json({ error: 'Content too short to summarize' }, { status: 400 })
  }

  // Hard cap to prevent runaway token costs
  const truncated = content.slice(0, 20000)

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': process.env.AI_API_KEY!,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5',
      max_tokens: 512,
      stream: true,
      messages: [{ role: 'user', content: `Summarize this in 3-5 sentences:\n\n${truncated}` }],
    }),
  })

  // Forward the stream directly to the client
  return new Response(response.body, {
    headers: { 'Content-Type': 'text/event-stream' },
  })
}
```

```tsx
// SummarizeButton.tsx
import { useRef, useState } from 'react'

const MIN_CHARS = 500

export function SummarizeButton({ content }: { content: string }) {
  const [summary, setSummary] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const abortRef = useRef<AbortController | null>(null)

  const tooShort = content.length < MIN_CHARS

  async function handleSummarize() {
    // Cancel any in-flight request before starting new one
    abortRef.current?.abort()
    abortRef.current = new AbortController()

    setSummary('')
    setError('')
    setLoading(true)

    try {
      const res = await fetch('/api/summarize', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ content }),
        signal: abortRef.current.signal,
      })

      if (!res.ok) {
        const { error } = await res.json()
        throw new Error(error)
      }

      // Read the SSE stream and accumulate text
      const reader = res.body!.getReader()
      const decoder = new TextDecoder()

      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        const chunk = decoder.decode(value)
        // Parse SSE lines: "data: {...}"
        for (const line of chunk.split('\n')) {
          if (!line.startsWith('data: ')) continue
          const data = line.slice(6)
          if (data === '[DONE]') break
          try {
            const json = JSON.parse(data)
            const delta = json.delta?.text ?? ''
            // Show partial text as it streams — don't wait for completion
            setSummary(prev => prev + delta)
          } catch {
            // ignore malformed SSE lines
          }
        }
      }
    } catch (err: unknown) {
      if (err instanceof Error && err.name === 'AbortError') return
      setError(err instanceof Error ? err.message : 'Summarization failed')
    } finally {
      setLoading(false)
    }
  }

  function handleCancel() {
    abortRef.current?.abort()
    setLoading(false)
  }

  return (
    <div>
      <div style={{ display: 'flex', gap: 8 }}>
        <button
          onClick={handleSummarize}
          disabled={loading || tooShort}
          title={tooShort ? `Content must be at least ${MIN_CHARS} characters` : undefined}
        >
          {loading ? 'Summarizing…' : 'Summarize'}
        </button>

        {/* Cancel button appears only while streaming */}
        {loading && (
          <button onClick={handleCancel}>Cancel</button>
        )}
      </div>

      {/* Show partial text while streaming — users read as it arrives */}
      {summary && (
        <div aria-live="polite" aria-label="Summary">
          {summary}
          {/* Blinking cursor while still streaming */}
          {loading && <span aria-hidden>▌</span>}
        </div>
      )}

      {error && <p role="alert" style={{ color: 'red' }}>{error}</p>}
    </div>
  )
}
```

## Key Rules
- Never call the AI provider directly from client code — API keys are exposed in the bundle.
- Always stream: users tolerate 10 seconds of streaming text; they abandon after 3 seconds of blank waiting.
- Gate on minimum content length before sending the request (saves cost and avoids useless summaries).
- Store an `AbortController` ref so clicking "Summarize" again cancels the previous in-flight request.
- Truncate input at a max character count server-side — never trust the client to do it.
- Show partial results as they arrive (`setSummary(prev => prev + delta)`), not all at once at the end.
- A blinking cursor or "Summarizing…" indicator during streaming tells the user work is in progress.
- The cancel button must dismiss cleanly — catch `AbortError` separately and do not show it as an error.
