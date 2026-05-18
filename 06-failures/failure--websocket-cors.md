# Failure: WebSocket CORS and Authentication Gaps

## Overview
WebSocket connections do not go through the browser's CORS preflight mechanism. The server receives the initial HTTP upgrade request with the `Origin` header, but the browser does not block the connection if the server omits CORS response headers — that's only for XHR/fetch. This means your CORS middleware does NOT protect WebSocket endpoints. The server must validate the `Origin` header manually. Authentication should use a token passed in the first message or via query string, not cookies (cookies are sent but enforcement depends on SameSite settings, not CORS).

## Why CORS Doesn't Apply to WebSocket

```
HTTP Request:             Browser checks CORS preflight headers
WebSocket Handshake:      Browser sends Origin header, but does NOT enforce CORS
                          → Server must check Origin itself
```

```ts
// BAD — CORS middleware protects HTTP routes but NOT WebSocket upgrades
app.use(cors({ origin: 'https://yourapp.com' }))  // has no effect on ws://

// The WebSocket server receives all connections regardless:
const wss = new WebSocketServer({ server })
wss.on('connection', (ws, req) => {
  // req.headers.origin = 'https://evil.com' — middleware didn't block this
  handleConnection(ws, req)
})
```

## Validate Origin Header Manually

```ts
const ALLOWED_ORIGINS = new Set([
  'https://yourapp.com',
  'https://www.yourapp.com',
  ...(process.env.NODE_ENV === 'development' ? ['http://localhost:3000'] : []),
])

wss.on('connection', (ws, req) => {
  const origin = req.headers.origin

  if (!origin || !ALLOWED_ORIGINS.has(origin)) {
    console.warn('WebSocket connection rejected: invalid origin', origin)
    ws.close(1008, 'Origin not allowed')
    return
  }

  handleConnection(ws, req)
})
```

The `origin` header is set by browsers but can be spoofed by non-browser clients (curl, scripts). Origin validation protects against CSRF from other websites, not against deliberate server-to-server attacks.

## Authentication: Token in First Message

Cookies are sent with WebSocket upgrade requests (subject to SameSite policy), but many setups prefer explicit token auth:

```ts
// Client: send auth token as first message
const ws = new WebSocket('wss://yourapi.com/ws')
ws.onopen = () => {
  ws.send(JSON.stringify({ type: 'auth', token: getAuthToken() }))
}

// Server: wait for auth message before allowing other messages
wss.on('connection', (ws, req) => {
  if (!validateOrigin(req)) { ws.close(1008, 'Origin not allowed'); return }

  let authenticated = false

  ws.on('message', (data) => {
    const message = JSON.parse(data.toString())

    if (!authenticated) {
      if (message.type !== 'auth') {
        ws.close(1008, 'Authentication required')
        return
      }
      const user = verifyToken(message.token)
      if (!user) {
        ws.close(1008, 'Invalid token')
        return
      }
      authenticated = true
      ws.userId = user.id
      ws.send(JSON.stringify({ type: 'auth_ok' }))
      return
    }

    // Handle authenticated messages
    handleMessage(ws, message)
  })

  // Auto-disconnect if no auth within 5 seconds
  const authTimeout = setTimeout(() => {
    if (!authenticated) ws.close(1008, 'Auth timeout')
  }, 5000)

  ws.on('close', () => clearTimeout(authTimeout))
})
```

## Token in Query String (Simpler, Less Secure)

```ts
// Client
const token = getAuthToken()
const ws = new WebSocket(`wss://yourapi.com/ws?token=${encodeURIComponent(token)}`)

// Server
const url = new URL(req.url!, `http://localhost`)
const token = url.searchParams.get('token')
const user = verifyToken(token)
```

Tokens in query strings appear in server logs. Use short-lived tokens (< 60s) when using this pattern.

## WSS Required on HTTPS Pages

Browsers block `ws://` (unencrypted) connections from `https://` pages — mixed content.

```ts
// Client
const wsUrl = window.location.protocol === 'https:'
  ? 'wss://yourapi.com/ws'
  : 'ws://localhost:3001/ws'
```

## Key Rules
- CORS middleware does not protect WebSocket endpoints — always validate `Origin` header manually
- Reject connections with missing or non-allowlisted Origin headers
- Prefer token-in-first-message over query string tokens (tokens in URLs appear in logs)
- Set a short timeout to close unauthenticated connections (5–10 seconds)
- WSS (WebSocket Secure) is required for HTTPS pages — configure TLS at the proxy/load balancer
- Cookies are sent with WebSocket upgrade but are not "enforced" by CORS — explicit token auth is more reliable
- Rate limit new WebSocket connections per IP to prevent connection exhaustion attacks
