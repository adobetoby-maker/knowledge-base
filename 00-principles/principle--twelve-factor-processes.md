# Principle: Twelve-Factor Processes

## Overview
The Twelve-Factor App methodology defines Factor VI: "Execute the app as one or more stateless processes." Stateless processes share nothing — they hold no in-memory state that must persist between requests and they do not share state with sibling processes. This single constraint is what makes horizontal scaling, rolling deploys, and crash recovery possible without data loss or inconsistency.

## What Stateless Processes Mean

Two process instances handling consecutive requests from the same user must produce identical results without coordinating with each other. The user's session data, cart contents, uploaded file — none of it lives in the process's memory between requests.

```
Request 1 → Process A (pod 1)
Request 2 → Process B (pod 2)  ← must have the same data as pod 1

If Process A holds session state in RAM, Process B cannot serve Request 2 correctly.
```

## What Must Move Out of Process Memory

| State type | Wrong (in-process) | Right (external service) |
|---|---|---|
| User sessions | In-memory session store | Redis / DynamoDB |
| Uploaded files | `/tmp` on the server | S3 / R2 / GCS |
| Job queue | In-memory queue | Redis Queue / SQS / BullMQ |
| Cache | Module-level Map | Redis / Memcached |
| WebSocket connections | In-process Set | Redis Pub/Sub for broadcasting |
| Rate limit counters | In-memory Map | Redis with INCR + TTL |

## The Sticky Session Anti-Pattern

Sticky sessions (also called "session affinity") are a load balancer configuration that routes all requests from a user to the same server. This is a band-aid that masks stateful process architecture:

- When that server restarts (deploy, crash, scaling event), the user loses their session
- You cannot scale down — you must keep all servers running to not lose users
- Rolling deploys become painful — you must wait for all sticky sessions to drain

Fix: use Redis for sessions. `connect-redis`, Supabase Auth (JWT in cookies), or any Redis-backed session store. The session data lives in Redis, not in the process.

```typescript
// Wrong: in-process sessions (breaks with multiple instances)
const sessions = new Map<string, UserSession>();
app.use((req, res, next) => {
  req.session = sessions.get(req.cookies.sid);
  next();
});

// Right: Redis-backed sessions
import session from "express-session";
import RedisStore from "connect-redis";
app.use(session({
  store: new RedisStore({ client: redisClient }),
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
}));
```

## File Uploads and the `/tmp` Trap

Serverless functions and containerized apps restart frequently. Files written to the local filesystem are lost on restart. Worse: in a multi-instance deployment, a file written by Instance A is not visible to Instance B.

```typescript
// Wrong: save to local disk
app.post("/upload", upload.single("file"), (req, res) => {
  // req.file.path is on THIS container's filesystem only
  res.json({ path: req.file.path }); // path is meaningless to other instances
});

// Right: stream directly to object storage
app.post("/upload", async (req, res) => {
  const key = `uploads/${crypto.randomUUID()}`;
  await s3.upload({ Bucket: process.env.S3_BUCKET, Key: key, Body: req }).promise();
  res.json({ key }); // any instance can fetch from S3
});
```

## In-Process Caches Are Still Valid (With Limits)

Read-only data initialized once at startup is fine in process memory:
```typescript
// OK: loaded once at startup, never mutated
const TAX_RATES = loadTaxRatesFromDB(); // read at boot, constant thereafter
```

In-process caches that are built up over time (growing Maps, LRU caches) are problematic: each instance builds its own cache cold, cache misses are not shared, and memory grows unboundedly. Use Redis for shared caches or accept that each instance has its own warm-up period with a bounded size.

## Key Rules
- No in-memory state that must survive a process restart
- Sessions → Redis or JWT (stateless tokens)
- Uploaded files → object storage immediately, never `/tmp` as a destination
- Job queues → external queue service, never in-process arrays
- WebSocket broadcast → Redis Pub/Sub so any instance can send to any connected client
- Test statelessness: kill one pod, verify users on other pods are unaffected
- If you need sticky sessions, that's a signal your process is stateful
