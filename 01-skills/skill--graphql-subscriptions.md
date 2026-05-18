# Skill: GraphQL Real-Time Subscriptions

## Overview
GraphQL subscriptions push data to clients when events occur, replacing polling. The architectural challenge: your API server may run many instances, so a subscription on instance A won't see events published on instance B. Redis pub/sub solves this by acting as a shared event bus. Without it, subscriptions work in dev (single instance) but silently miss events in production.

## Implementation

### 1. Server setup with graphql-ws
```ts
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import { useServer } from 'graphql-ws/lib/use/ws';
import { schema } from './schema';
import { createContext } from './context';

const httpServer = createServer(app);
const wsServer = new WebSocketServer({ server: httpServer, path: '/graphql' });

useServer(
  {
    schema,
    context: async (ctx) => {
      // Authenticate WebSocket connections via token in connectionParams
      const token = ctx.connectionParams?.authorization as string;
      const user = await verifyToken(token);
      if (!user) throw new Error('Unauthorized');
      return createContext(user);
    },
    onConnect: async (ctx) => {
      console.log('WS connected');
    },
    onDisconnect: (ctx, code, reason) => {
      // Cleanup runs here — subscriptions auto-dispose via async generator
      console.log('WS disconnected', code, reason);
    },
  },
  wsServer
);

httpServer.listen(4000);
```

### 2. Redis pub/sub for multi-instance broadcasting
```ts
import { createClient } from 'redis';
import { PubSub } from 'graphql-subscriptions';
import { RedisPubSub } from 'graphql-redis-subscriptions';

// Separate publisher and subscriber clients (Redis requires separate connections for pub/sub)
const publisher = createClient({ url: process.env.REDIS_URL });
const subscriber = createClient({ url: process.env.REDIS_URL });
await publisher.connect();
await subscriber.connect();

const pubsub = new RedisPubSub({
  publisher,
  subscriber,
});

// When an event happens anywhere in your system, publish to Redis
export async function notifyOrderUpdated(order: Order) {
  await pubsub.publish('ORDER_UPDATED', { orderUpdated: order });
}
```

### 3. Subscription resolver with filtering
```ts
builder.subscriptionType({
  fields: (t) => ({
    orderUpdated: t.field({
      type: OrderType,
      args: {
        orderId: t.arg.id({ required: true }),
      },
      subscribe: (_root, args, ctx) => {
        // Filter: only deliver events for the requested order
        return pubsub.asyncIterator(['ORDER_UPDATED'], {
          filter: (payload: { orderUpdated: Order }) =>
            payload.orderUpdated.id === args.orderId &&
            payload.orderUpdated.userId === ctx.userId,  // ownership check
        });
      },
      resolve: (payload) => payload.orderUpdated,
    }),
  }),
});
```

### 4. Client subscription (graphql-ws)
```ts
import { createClient } from 'graphql-ws';

const client = createClient({
  url: 'wss://api.example.com/graphql',
  connectionParams: {
    authorization: getAuthToken(),
  },
  retryAttempts: 5,
  on: {
    connected: () => console.log('Subscriptions connected'),
    closed: () => console.log('Subscriptions closed'),
  },
});

const unsubscribe = client.subscribe(
  {
    query: `subscription OrderUpdated($orderId: ID!) {
      orderUpdated(orderId: $orderId) { id status updatedAt }
    }`,
    variables: { orderId },
  },
  {
    next: (data) => updateUI(data.data?.orderUpdated),
    error: (err) => console.error('Subscription error:', err),
    complete: () => console.log('Subscription complete'),
  }
);

// Call when component unmounts
onDestroy(() => unsubscribe());
```

### 5. Testing with wscat
```bash
# Install wscat
npm install -g wscat

# Connect and subscribe
wscat -c "ws://localhost:4000/graphql" \
  -H "Sec-WebSocket-Protocol: graphql-transport-ws"

# After connecting, send connection_init
{"type":"connection_init","payload":{"authorization":"Bearer TOKEN"}}

# Subscribe
{"id":"1","type":"subscribe","payload":{"query":"subscription { orderUpdated(orderId:\"123\") { id status } }"}}
```

## Key Rules
- **Use Redis pub/sub for any multi-instance deployment** — `graphql-subscriptions` in-memory PubSub only works on a single process.
- **Filter in the subscription resolver**, not the client — sending unnecessary events wastes bandwidth and risks data leaks.
- **Always authenticate WebSocket connections** — HTTP auth middleware doesn't run for WS upgrades; check `connectionParams`.
- Separate Redis publisher and subscriber clients — subscribing and publishing on the same client blocks the event loop.
- Clean up subscriptions on client unmount — async iterators are not garbage collected automatically.
- Don't use subscriptions for data that can be polled every 5s — subscriptions are stateful and expensive. Use them for latency-sensitive events.
- Set `retryAttempts` on the client — WS connections drop on network changes; silent disconnects cause missed events.
