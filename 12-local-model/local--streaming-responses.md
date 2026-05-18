# Local Model: Streaming Responses from Local Models

## Overview
Streaming returns tokens as they are generated instead of waiting for the full response. For local models that generate 20-80 tokens/second, the difference between streaming and non-streaming is the difference between seeing text appear immediately vs waiting 5-30 seconds for a blank screen to populate. For user-facing applications, streaming is non-negotiable.

## Implementation / Key Points

### Ollama Streaming (HTTP)
```typescript
// POST /api/generate with stream: true
const response = await fetch('http://localhost:11434/api/generate', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    model: 'llama3.1:8b',
    prompt: userInput,
    stream: true,
  }),
});

if (!response.body) throw new Error('No response body');

const reader = response.body.getReader();
const decoder = new TextDecoder();
let fullResponse = '';

while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  
  const chunk = decoder.decode(value);
  // Each chunk is a JSON line: {"response": " token", "done": false}
  for (const line of chunk.split('\n').filter(Boolean)) {
    const data = JSON.parse(line);
    fullResponse += data.response;
    onToken(data.response);  // update UI with each token
    if (data.done) break;
  }
}
```

### llama.cpp Server Streaming
```typescript
// POST /completion with stream: true
const response = await fetch('http://localhost:8080/completion', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    prompt: fullPrompt,
    stream: true,
    n_predict: 512,
  }),
});

// Server-Sent Events format
const reader = response.body!.getReader();
// Each chunk: "data: {"content": " token"}\n\n"
```

### Async Generator Pattern (TypeScript)
```typescript
async function* streamOllama(prompt: string): AsyncGenerator<string> {
  const response = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({ model: 'llama3.1:8b', prompt, stream: true }),
  });
  
  const reader = response.body!.getReader();
  const decoder = new TextDecoder();
  
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      const chunk = decoder.decode(value);
      for (const line of chunk.split('\n').filter(Boolean)) {
        const data = JSON.parse(line);
        if (data.response) yield data.response;
        if (data.done) return;
      }
    }
  } finally {
    reader.releaseLock();
  }
}

// Usage
for await (const token of streamOllama('Explain quantum entanglement')) {
  process.stdout.write(token);
}
```

### Abort / Cancel on User Action
```typescript
let abortController: AbortController | null = null;

function startStream(prompt: string) {
  abortController = new AbortController();
  
  const response = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    signal: abortController.signal,  // pass abort signal
    body: JSON.stringify({ model: 'llama3.1:8b', prompt, stream: true }),
  });
  // ...
}

function cancelStream() {
  abortController?.abort();
}
```

### React Integration
```typescript
function ChatMessage({ prompt }: { prompt: string }) {
  const [text, setText] = useState('');
  const [done, setDone] = useState(false);
  
  useEffect(() => {
    let cancelled = false;
    
    (async () => {
      for await (const token of streamOllama(prompt)) {
        if (cancelled) break;
        setText(prev => prev + token);
      }
      if (!cancelled) setDone(true);
    })();
    
    return () => { cancelled = true; };  // cleanup on unmount
  }, [prompt]);
  
  return <p>{text}{!done && <span className="cursor">▊</span>}</p>;
}
```

### Partial Response Display Strategies
- **Append token**: simplest, append each token to a string
- **Buffer and flush**: batch tokens every 50ms to reduce React re-renders
- **Markdown-aware**: detect complete markdown elements before rendering to avoid half-rendered headers

## Key Rules
- Always use streaming for user-facing interfaces — waiting 10 seconds for a blank screen is unacceptable UX
- Release the reader lock in a `finally` block to prevent resource leaks
- Pass an AbortController signal so users can cancel generation without leaving a zombie stream
- Cleanup streaming on component unmount — set a `cancelled` flag and break out of the loop
- Parse NDJSON (newline-delimited JSON) carefully — chunks may contain multiple lines or split a line
- Buffer React state updates to avoid re-rendering on every token (every 50-100ms is sufficient)
