# Principle: Shared-Nothing Architecture

## The Scaling Problem With Stateful Servers

When a server stores session state in memory — logged-in user data, cart contents, partial upload state — it works fine for one instance. The moment you add a second instance, you have a problem: a user's next request might land on the other instance, which has no record of their session. You're forced to use **sticky sessions** (routing the same user to the same instance) as a workaround.

Sticky sessions break several important capabilities:
- You can't take an instance offline without dropping active sessions.
- You can't distribute load freely — hot users stay on hot instances.
- Blue-green and canary deployments become much harder to manage safely.
- Auto-scaling adds new instances that can't serve existing users until their sessions expire.

The root cause is the same in every case: state that belongs to the user is stored where it doesn't belong — in the compute layer.

## Move State Out of Servers

Stateless servers hold no per-user data in memory between requests. All state lives in an external store:

- **Sessions** → Redis (TTL-managed, fast reads) or signed cookies (no server storage needed, tamper-proof with `HMAC`)
- **User data** → database
- **File uploads** → object storage (S3, R2, Supabase Storage); accept the chunk, stream directly to storage
- **Long-running job state** → database or queue with explicit job records
- **WebSocket presence** → Redis Pub/Sub or a dedicated presence service

Once state is external, any server instance can serve any request. You can add instances freely and remove them without user impact.

## How This Enables Blue-Green Deployment

Blue-green deployment runs two identical environments (blue = current production, green = new version). Traffic switches from blue to green at the load balancer level, atomically or gradually.

With stateful servers, switching mid-session drops active users. With stateless servers, the switch is seamless — the new instances read from the same Redis and same database that the old ones used. Sessions continue uninterrupted.

This also enables **rolling deployments** (replace one instance at a time) and **canary releases** (send 5% of traffic to new version while 95% runs old version). Both require that any instance can handle any request.

## Designing Stateless APIs

```typescript
// BAD — state in server memory
const sessions = new Map<string, UserSession>(); // dies on restart, breaks multi-instance

app.post("/login", (req, res) => {
  const session = createSession(req.body);
  sessions.set(session.id, session);
  res.cookie("session_id", session.id);
});

// GOOD — state in Redis with TTL
app.post("/login", async (req, res) => {
  const session = createSession(req.body);
  await redis.setex(`session:${session.id}`, 3600, JSON.stringify(session));
  res.cookie("session_id", session.id, { httpOnly: true, secure: true });
});

// EVEN BETTER for simple auth — signed JWT in cookie, no server storage at all
app.post("/login", async (req, res) => {
  const payload = { userId: user.id, email: user.email };
  const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: "1h" });
  res.cookie("auth_token", token, { httpOnly: true, secure: true });
});
```

## What "Nothing" Means

"Shared nothing" doesn't mean no shared state ever — databases and caches are shared. It means each compute node holds no state that another node needs. Nodes communicate only through external stores and message queues, never through direct node-to-node connections for application state.

The exception is coordination state (distributed locks, leader election) which is also handled through external stores (Redis SETNX, database advisory locks), not in-memory.

## Key Rules

- **No per-request state stored in server memory** — it won't survive a restart or a second instance.
- **Sessions go to Redis or signed cookies** — not server-side memory.
- **Design for any instance handling any request** — if it requires sticky sessions, fix the architecture.
- **Uploads stream directly to object storage** — don't buffer entire files in memory.
- **Stateless servers enable blue-green and canary** — stateful servers block both.
- **Test with two instances locally** — run your app on ports 3000 and 3001 behind a round-robin proxy; login failures expose stateful code immediately.
- **Health checks must be instance-local** — they check this instance's readiness, not the database's health (that's a different concern).
