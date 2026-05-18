# Skill: Server-Sent Events (SSE) Streaming

## Overview
SSE streams data from server to client over a single long-lived HTTP connection. Unlike WebSockets, SSE is unidirectional (server → client only), HTTP-native (works through proxies/CDNs without upgrade headers), and auto-reconnects via `EventSource`. Use SSE for live feeds, AI response streaming, progress updates. Use WebSockets when you need bidirectional communication.

## Implementation

### 1. Server: SSE response handler (Node/Next.js Route Handler)
```ts
// app/api/stream/route.ts
export async function GET(req: Request) {
  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    async start(controller) {
      const send = (event: string, data: unknown, id?: string) => {
        let chunk = '';
        if (id) chunk += `id: ${id}\n`;
        chunk += `event: ${event}\n`;
        chunk += `data: ${JSON.stringify(data)}\n\n`;  // double newline ends event
        controller.enqueue(encoder.encode(chunk));
      };

      // Keep-alive comment every 15s — prevents proxy timeouts
      const keepAlive = setInterval(() => {
        controller.enqueue(encoder.encode(': ping\n\n'));
      }, 15_000);

      // Clean up on client disconnect
      req.signal.addEventListener('abort', () => {
        clearInterval(keepAlive);
        controller.close();
      });

      try {
        // Example: stream data
        for await (const chunk of dataSource()) {
          send('update', chunk, String(chunk.id));  // id enables resumability
        }
        send('done', { finished: true });
        controller.close();
      } catch (err) {
        send('error', { message: 'Stream error' });
        controller.close();
      } finally {
        clearInterval(keepAlive);
      }
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no',  // disable nginx buffering
    },
  });
}
```

### 2. Client: EventSource with reconnect and resumability
```ts
class SSEClient {
  private es: EventSource | null = null;
  private lastEventId: string | null = null;

  connect(url: string) {
    // Append Last-Event-ID so server can resume from last seen event
    const fullUrl = this.lastEventId
      ? `${url}?lastEventId=${this.lastEventId}`
      : url;

    this.es = new EventSource(fullUrl);

    // EventSource auto-reconnects on close — but track last ID for resumability
    this.es.addEventListener('update', (e: MessageEvent) => {
      this.lastEventId = e.lastEventId;
      this.handleUpdate(JSON.parse(e.data));
    });

    this.es.addEventListener('done', () => {
      this.es?.close();
    });

    this.es.onerror = (err) => {
      // EventSource retries automatically — onerror fires on each failed attempt
      console.warn('SSE error, will retry:', err);
    };
  }

  disconnect() {
    this.es?.close();
    this.es = null;
  }
}
```

### 3. SSE format reference
```
id: 42\n
event: update\n
data: {"key":"value"}\n
\n                          ← blank line ends the event

: this is a comment\n       ← keep-alive, ignored by client
\n

retry: 3000\n               ← tell client to retry in 3s (default is 3s)
\n
```

## Key Rules
- **Always send keep-alives every 15s** — proxies and CDNs close idle connections, EventSource reconnects but you lose in-flight events.
- Set `X-Accel-Buffering: no` for nginx and `Cache-Control: no-cache` — buffering breaks streaming.
- **Listen to `req.signal` (abort) to clean up** — without it, keepAlive intervals and DB cursors leak on disconnect.
- Use event IDs (`id:`) for anything that must be resumable — client sends `Last-Event-ID` header on reconnect; use it to replay missed events.
- SSE is HTTP/1.1 — browsers limit to 6 connections per origin. In HTTP/2, the limit is ~100. Don't open multiple SSE streams to the same origin in old browsers.
- Prefer SSE over WebSockets when: connection is server→client only, you need HTTP auth headers, you're behind a standard HTTP proxy/CDN.
- Prefer WebSockets when: client sends frequent messages, latency < 50ms matters, binary frames needed.
