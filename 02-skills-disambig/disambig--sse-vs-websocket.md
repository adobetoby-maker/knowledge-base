# Disambig: SSE vs WebSocket

## Overview
Server-Sent Events (SSE) and WebSockets both enable real-time data from server to client, but they operate on fundamentally different models. SSE is one-directional (server pushes), runs over HTTP, and is trivial to implement. WebSocket is bidirectional, upgrades to its own protocol, and requires more infrastructure. Choosing WebSocket for a use case that's actually one-directional adds complexity with no benefit—and SSE handles the most common real-time pattern (AI streaming, live feeds, notifications) cleanly.

## Comparison

| Property | SSE | WebSocket |
|---|---|---|
| Direction | Server → Client only | Bidirectional |
| Protocol | HTTP/1.1 or HTTP/2 | `ws://` / `wss://` (separate protocol) |
| Browser API | `EventSource` (built-in) | `WebSocket` (built-in) |
| Auto-reconnect | Built into EventSource | Manual implementation required |
| HTTP/2 | Multiplexed (many SSE streams per connection) | One connection per WebSocket |
| Proxy / CDN | Works through standard HTTP proxies | Requires WebSocket support |
| Binary support | Text only (base64 encode for binary) | Native binary (ArrayBuffer) |
| Load balancing | Standard HTTP (any balancer) | Sticky sessions often required |
| Authentication | Standard headers on initial request | Header auth or first-message auth |
| Server implementation | Simple (`res.write()` loop) | Requires WS server or library |

## When to Use SSE

```
AI response streaming (ChatGPT-style)
→ SSE: server streams tokens to client; client never sends mid-stream; perfect fit

Live activity feeds (Twitter/X timeline, news feed)
→ SSE: server pushes new items; client interaction is separate API calls

Deployment / build progress logs
→ SSE: server streams log lines; client just displays them

Stock prices, sports scores, sensor readings
→ SSE: server pushes updates; client doesn't need to send data in the stream

Push notifications (in-browser, not mobile)
→ SSE: simple one-way channel; auto-reconnects on network drop
```

## When to Use WebSocket

```
Chat applications
→ WebSocket: user sends messages AND receives messages on same connection

Collaborative editing (Google Docs-style)
→ WebSocket: user edits flow both directions; operational transforms require bidirectional sync

Multiplayer games
→ WebSocket: game state flows both directions at high frequency; binary efficiency needed

Live trading / order books
→ WebSocket: user sends orders, server streams market data; both directions required

Collaborative cursor / presence (Figma-style)
→ WebSocket: every user's cursor position must flow to every other user
```

## SSE Implementation
```ts
// Server (Node.js / Next.js Route Handler)
export async function GET(req: Request) {
  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    async start(controller) {
      // Send an event
      const sendEvent = (data: string, event?: string) => {
        const lines = [
          event ? `event: ${event}` : '',
          `data: ${data}`,
          '',  // blank line terminates event
          '',
        ].filter(Boolean).join('\n');
        controller.enqueue(encoder.encode(lines + '\n'));
      };

      for await (const chunk of generateAIResponse()) {
        sendEvent(JSON.stringify({ chunk }), 'message');
      }
      sendEvent('[DONE]', 'done');
      controller.close();
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  });
}

// Client
const es = new EventSource('/api/stream');
es.addEventListener('message', (e) => {
  const { chunk } = JSON.parse(e.data);
  appendToUI(chunk);
});
es.addEventListener('done', () => es.close());
es.onerror = () => {
  // EventSource auto-reconnects after 3s by default
  console.log('SSE error — will reconnect automatically');
};
```

## WebSocket Implementation (socket.io)
```ts
// When you actually need bidirectional
import { Server } from 'socket.io';

const io = new Server(httpServer, { cors: { origin: '*' } });

io.on('connection', (socket) => {
  socket.on('chat:message', (msg) => {
    // Broadcast to room
    io.to(msg.roomId).emit('chat:message', {
      ...msg,
      sender: socket.data.userId,
      timestamp: Date.now(),
    });
  });

  socket.on('disconnect', () => {
    // Handle cleanup
  });
});
```

## Key Rules
- **SSE first** — if the client doesn't send data in the stream, SSE is almost always correct and simpler.
- **WebSocket only for bidirectional** — upgrading to WebSocket for a one-directional feed adds complexity with no benefit.
- **SSE auto-reconnects** — `EventSource` reconnects automatically; WebSocket reconnection is your code to write.
- **SSE works through load balancers** — WebSocket connections are stateful; load balancers need sticky session or WS proxy config.
- **SSE with HTTP/2 is efficient** — multiple SSE streams share one HTTP/2 connection; no connection limit problem.
- **Binary data with WebSocket** — SSE is text-only; for audio, video, or binary frames, WebSocket is the right choice.
