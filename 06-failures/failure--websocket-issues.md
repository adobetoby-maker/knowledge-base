# Failure: WebSocket Common Issues

## Connection Issues

### Symptom: Connection refused on Vercel / serverless

Serverless functions are stateless — WebSocket connections require a persistent process. Vercel doesn't support WebSocket servers in API routes.

**Fix**: Use Supabase Realtime, Ably, Pusher, or a dedicated WebSocket service. Or use Vercel Edge with Cloudflare for Durable Objects (supports stateful WebSockets).

### Symptom: WebSocket closes after 60 seconds

Idle WebSocket connections are closed by load balancers, proxies, and serverless platforms with inactivity timeouts.

**Fix**: Send periodic pings:

```ts
// Client
const ws = new WebSocket(url)

const pingInterval = setInterval(() => {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type: 'ping' }))
  }
}, 30_000)

ws.onclose = () => clearInterval(pingInterval)
```

```ts
// Server (socket.io or ws)
wss.on('connection', socket => {
  socket.on('message', data => {
    const msg = JSON.parse(data.toString())
    if (msg.type === 'ping') {
      socket.send(JSON.stringify({ type: 'pong' }))
    }
  })
})
```

## Reconnection

### Symptom: No automatic reconnect on network loss

Native WebSocket doesn't reconnect. Users lose real-time updates silently after a brief network interruption.

**Fix**: Implement reconnect with exponential backoff:

```ts
class ReconnectingWebSocket {
  private ws: WebSocket | null = null
  private reconnectDelay = 1000
  private maxDelay = 30_000

  constructor(private url: string, private onMessage: (data: unknown) => void) {
    this.connect()
  }

  private connect() {
    this.ws = new WebSocket(this.url)

    this.ws.onmessage = e => {
      this.reconnectDelay = 1000  // Reset delay on success
      this.onMessage(JSON.parse(e.data))
    }

    this.ws.onclose = () => {
      setTimeout(() => {
        this.reconnectDelay = Math.min(this.reconnectDelay * 2, this.maxDelay)
        this.connect()
      }, this.reconnectDelay)
    }
  }

  send(data: unknown) {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(data))
    }
  }

  close() {
    this.ws?.close()
  }
}
```

## Authentication

### Symptom: Can't send auth token in headers

WebSocket upgrade requests from the browser can't set custom headers. `Authorization: Bearer ...` is impossible from `new WebSocket(url)`.

**Fix options**:

1. **Token in URL query param** (simple but token appears in logs):
   ```ts
   const ws = new WebSocket(`wss://api.example.com/ws?token=${token}`)
   // Server extracts and validates token from URL
   ```

2. **First message as auth** (recommended):
   ```ts
   ws.onopen = () => {
     ws.send(JSON.stringify({ type: 'auth', token: getAuthToken() }))
   }
   ```
   Server rejects non-auth first messages and closes connection.

3. **Cookie auth**: If the WebSocket is same-origin, cookies are sent automatically.

## Memory Leaks

### Symptom: React component WebSocket not cleaning up

```tsx
// BAD: WebSocket created on every render, never closed
function LiveFeed() {
  const ws = new WebSocket(url)  // New connection on every render!
  ws.onmessage = e => setData(JSON.parse(e.data))
}

// GOOD: Create once, clean up on unmount
function LiveFeed() {
  useEffect(() => {
    const ws = new WebSocket(url)
    ws.onmessage = e => setData(JSON.parse(e.data))
    return () => ws.close()  // Cleanup
  }, [])
}
```

## Message Ordering

WebSocket messages can arrive out of order on unreliable networks. Add sequence numbers for critical messages:

```ts
// Server sends messages with sequence numbers
socket.send(JSON.stringify({ seq: ++seqNum, type: 'update', data }))

// Client detects gaps
ws.onmessage = e => {
  const msg = JSON.parse(e.data)
  if (msg.seq !== expectedSeq) {
    // Request resync or ignore out-of-order messages
  }
  expectedSeq = msg.seq + 1
}
```

## Key Rules

- WebSocket connections need periodic pings to survive load balancer idle timeouts.
- Always clean up WebSocket connections in React's `useEffect` cleanup function.
- Serverless deployments can't host WebSocket servers — use a managed service (Supabase Realtime, Ably, Pusher).
- Authentication must be done via URL token or first-message auth — browser WebSocket can't set custom headers.
