# Streaming Tokens from Local Model Inference

## Why Streaming Matters

Non-streaming local inference blocks the UI for 2–30 seconds depending on model size and output length. Users interpret blank UI as a crash. Streaming shows the first token in ~100–500ms, signaling that the system is working. Even slow generation feels responsive when tokens appear progressively.

For long outputs (summaries, code, essays) streaming is non-negotiable. For short outputs (<20 tokens) streaming adds complexity with minimal UX benefit — evaluate whether the use case warrants it.

## Ollama Streaming API

Ollama's `/api/generate` endpoint returns a stream of JSON objects when `stream: true` (the default). Each line is a complete JSON object:

```
{"model":"llama3","response":"The ","done":false}
{"model":"llama3","response":"answer ","done":false}
{"model":"llama3","response":"is","done":true,"total_duration":1234567}
```

Use `fetch` with streaming body reading:

```js
const response = await fetch('http://localhost:11434/api/generate', {
  method: 'POST',
  body: JSON.stringify({ model: 'llama3', prompt: userPrompt, stream: true }),
});
const reader = response.body.getReader();
const decoder = new TextDecoder();
while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  const lines = decoder.decode(value).split('\n').filter(Boolean);
  for (const line of lines) {
    const obj = JSON.parse(line);
    yield obj.response; // emit each token fragment
    if (obj.done) return;
  }
}
```

## Server-Sent Events to Browser

SSE (Server-Sent Events) is the standard pattern for pushing streaming text from server to browser over HTTP. It's simpler than WebSockets for one-directional streaming.

Server (Node/Express):
```js
res.setHeader('Content-Type', 'text/event-stream');
res.setHeader('Cache-Control', 'no-cache');
res.setHeader('Connection', 'keep-alive');
for await (const token of ollamaStream(prompt)) {
  res.write(`data: ${JSON.stringify({ token })}\n\n`);
}
res.write('data: [DONE]\n\n');
res.end();
```

Client:
```js
const es = new EventSource('/api/generate?prompt=...');
es.onmessage = (e) => {
  if (e.data === '[DONE]') { es.close(); return; }
  appendToDisplay(JSON.parse(e.data).token);
};
```

SSE reconnects automatically on connection drop — add a `Last-Event-ID` header to resume from the last token if your use case requires resumability.

## Token-by-Token Display

Accumulate tokens in a ref/variable and set the UI state on each token. Don't re-render the full response on every token in a framework that diffs the DOM — instead, append to a `<span>` directly or use a streaming-aware component that only appends.

Add a blinking cursor (`|`) after the last character while streaming; remove it on completion. This is the standard affordance that communicates "still generating."

## Stopping Generation Early

Trigger early stop when:
- A stop sequence is matched (e.g., the model outputs `</answer>` in a structured format)
- User clicks a stop button
- A safety filter matches the accumulated output

For stop sequences: pass `stop: ["</answer>", "\n\nUser:"]` in the Ollama request. Ollama halts generation and sets `done: true` when any stop sequence is produced.

For user-triggered stop: abort the fetch with `AbortController`. This closes the connection; Ollama stops generating within one token cycle.

```js
const controller = new AbortController();
const response = await fetch('/api/generate', { signal: controller.signal });
// User clicks stop:
controller.abort();
```

## Cancellation

Always clean up on component unmount or navigation away — an orphaned stream keeps the model generating and consuming GPU resources. In React:

```js
useEffect(() => {
  const controller = new AbortController();
  startStream(prompt, controller.signal);
  return () => controller.abort(); // cleanup
}, [prompt]);
```

On the server, detect `req.on('close', ...)` to abort the upstream Ollama request when the client disconnects.

## Key Rules

- Default to streaming for any output expected to exceed 20 tokens; non-streaming blocks the UI visibly.
- Read Ollama's NDJSON stream line-by-line; don't buffer the entire response before parsing.
- Use SSE for server-to-browser streaming; it handles reconnection automatically and requires no special client library.
- Always pass an `AbortController` signal and clean up on component unmount — abandoned streams waste GPU time.
- Use `stop` sequences in the request for structured output formats; don't rely on post-processing to truncate.
- Show a streaming cursor while generating; remove it on done — this is the expected visual affordance.
