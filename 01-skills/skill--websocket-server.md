# Skill: WebSocket Server with Heartbeat

## Overview
WebSockets maintain persistent bidirectional connections, but TCP connections can silently die (NAT timeout, mobile network switches, proxy drops). Without a heartbeat, the server holds dead connections indefinitely, leaking memory and sending to nobody. A proper connection registry also enables targeted sends and graceful shutdown.

## Implementation

### 1. Server setup with heartbeat
```ts
import { WebSocketServer, WebSocket } from 'ws';
import { randomUUID } from 'crypto';

interface Client {
  id: string;
  ws: WebSocket;
  userId?: string;
  isAlive: boolean;
}

const clients = new Map<string, Client>();
const wss = new WebSocketServer({ port: 8080 });

// Ping all clients every 30s — detect stale connections
const heartbeat = setInterval(() => {
  for (const [id, client] of clients) {
    if (!client.isAlive) {
      // Missed previous ping — connection is dead
      client.ws.terminate();
      clients.delete(id);
      return;
    }
    client.isAlive = false;
    client.ws.ping();  // client must respond with pong
  }
}, 30_000);

wss.on('connection', (ws, req) => {
  const id = randomUUID();
  const client: Client = { id, ws, isAlive: true };
  clients.set(id, client);

  ws.on('pong', () => {
    // Client responded — mark alive
    const c = clients.get(id);
    if (c) c.isAlive = true;
  });

  ws.on('message', (data) => {
    const msg = JSON.parse(data.toString());
    handleMessage(client, msg);
  });

  ws.on('close', () => {
    clients.delete(id);
  });

  ws.on('error', () => {
    clients.delete(id);
    ws.terminate();
  });
});

wss.on('close', () => clearInterval(heartbeat));
```

### 2. Broadcast and targeted send
```ts
function broadcast(payload: object, excludeId?: string) {
  const data = JSON.stringify(payload);
  for (const [id, client] of clients) {
    if (id === excludeId) continue;
    if (client.ws.readyState === WebSocket.OPEN) {
      client.ws.send(data);
    }
  }
}

function sendTo(userId: string, payload: object) {
  const data = JSON.stringify(payload);
  for (const client of clients.values()) {
    if (client.userId === userId && client.ws.readyState === WebSocket.OPEN) {
      client.ws.send(data);
    }
  }
}
```

### 3. Graceful shutdown
```ts
async function shutdown() {
  clearInterval(heartbeat);
  
  // Close all connections before exiting
  for (const client of clients.values()) {
    client.ws.close(1001, 'Server shutting down');
  }
  
  await new Promise<void>(resolve => wss.close(() => resolve()));
  process.exit(0);
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
```

### 4. Client reconnect with exponential backoff
```ts
class ReconnectingWebSocket {
  private ws: WebSocket | null = null;
  private attempts = 0;

  connect() {
    this.ws = new WebSocket(WS_URL);

    this.ws.onopen = () => {
      this.attempts = 0;  // reset on success
    };

    this.ws.onclose = () => {
      const delay = Math.min(1000 * 2 ** this.attempts, 30_000);  // cap at 30s
      this.attempts++;
      setTimeout(() => this.connect(), delay);
    };
  }
}
```

## Key Rules
- **Heartbeat every 30s** — match or be shorter than your load balancer's idle timeout (often 60s).
- Always check `ws.readyState === WebSocket.OPEN` before sending — closed sockets throw.
- Use `terminate()` for dead connections (immediate TCP close), `close()` for clean handshake.
- Store `userId` on the client object after authentication message, not in the connection URL (URL shows in logs).
- For multi-instance setups, use Redis pub/sub to relay messages between nodes — `Map<id, ws>` is per-process only.
- Never send raw errors to clients — sanitize before sending; stack traces leak internals.
- Send a connection ID back to the client on connect so it can rehydrate state on reconnect.
