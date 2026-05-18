# Failure: WebSocket Reconnection Failures

## Why Reconnection Is Harder Than Connection

Opening a WebSocket is one line of code. Keeping it alive — and recovering cleanly when it drops — requires a state machine. The failure modes aren't network problems; they're application problems: missed messages, duplicate subscriptions, hammering a server that's already under load.

## Exponential Backoff (Don't Hammer the Server)

The instinct after a disconnect is to reconnect immediately. On a server restart or brief network blip, every client does this simultaneously, creating a thundering herd that prevents the server from recovering.

Use exponential backoff with jitter:

```ts
let attempts = 0;

function scheduleReconnect() {
  const base = Math.min(1000 * 2 ** attempts, 30_000); // cap at 30s
  const delay = base + Math.random() * 1000;           // add jitter
  attempts++;
  setTimeout(connect, delay);
}

ws.addEventListener('close', scheduleReconnect);
```

Reset `attempts = 0` on a successful connection. Cap the maximum delay — 30 seconds is reasonable; 5 minutes is too long for a live app.

## Re-subscribing After Reconnect

After reconnect, the server has no memory of the previous session. Room subscriptions, channel joins, and auth tokens must all be re-sent. Forgetting this means the UI appears connected but receives no events.

Keep subscription state in your application, not in the WebSocket object:

```ts
const subscriptions = new Set<string>();

function subscribe(room: string) {
  subscriptions.add(room);
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type: 'subscribe', room }));
  }
  // If not open, it will be sent on reconnect
}

function onOpen() {
  attempts = 0;
  // Re-send all subscriptions
  for (const room of subscriptions) {
    ws.send(JSON.stringify({ type: 'subscribe', room }));
  }
}
```

This pattern is the difference between a resilient client and one that silently stops receiving data.

## Message Queue During Disconnect

Messages sent while disconnected are dropped unless queued. For non-critical events this is acceptable. For anything the user expects to land (chat message, form submission, action), queue and drain on reconnect:

```ts
const outbox: string[] = [];

function send(msg: object) {
  const serialized = JSON.stringify(msg);
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(serialized);
  } else {
    outbox.push(serialized);
  }
}

function onOpen() {
  while (outbox.length) {
    ws.send(outbox.shift()!);
  }
}
```

Cap the outbox size. A user who goes offline for 10 minutes shouldn't flood the server with stale messages on reconnect. Drop the oldest when the cap is hit.

## Ping/Pong Keepalive

Some proxies (Nginx, Cloudflare, load balancers) close idle WebSocket connections after 60–120 seconds. The TCP connection drops with no close frame, so `ws.onclose` never fires and the client believes it's still connected.

Send application-level pings periodically:

```ts
const PING_INTERVAL = 25_000; // under most proxy timeouts

let pingTimer = setInterval(() => {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type: 'ping' }));
  }
}, PING_INTERVAL);

// Clear on intentional close
ws.addEventListener('close', () => clearInterval(pingTimer));
```

Track the last pong. If no pong arrives within 10 seconds of a ping, force-close the socket and trigger reconnect — it's silently dead.

## Key Rules

- **Always use exponential backoff with jitter** — never reconnect in a tight loop or all clients at once.
- **Store subscriptions in application state**, not in the socket — re-subscribe after every reconnect.
- **Queue unsent messages** when disconnected and drain on reconnect (with a size cap).
- **Implement application-level keepalive** — proxy idle timeouts will silently kill connections without a close frame.
- **Track connection state explicitly** — `WebSocket.readyState` is the ground truth, not a local `isConnected` boolean that can drift.
