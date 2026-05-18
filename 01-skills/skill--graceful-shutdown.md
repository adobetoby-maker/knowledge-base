# Skill: Graceful Process Shutdown

## Overview
Kubernetes and orchestration platforms stop processes by sending SIGTERM. A process that exits immediately drops in-flight requests, leaves database connections dangling, and loses buffered observability data. Graceful shutdown: stop accepting new requests, drain existing ones, close connections cleanly, flush buffers, then exit.

## Implementation

### Node.js / Express
```typescript
// server.ts
import express from "express";
import { pool } from "./db";
import * as Sentry from "@sentry/node";

const app = express();
const server = app.listen(3000, () => console.log("Listening on :3000"));

// Track in-flight requests
let connections = 0;
app.use((req, res, next) => {
  connections++;
  res.on("finish", () => connections--);
  next();
});

async function shutdown(signal: string) {
  console.log(`${signal} received — starting graceful shutdown`);

  // 1. Stop accepting new connections
  server.close(() => console.log("HTTP server closed"));

  // 2. Wait for in-flight requests (max 30s)
  const deadline = Date.now() + 30_000;
  while (connections > 0 && Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, 100));
  }
  if (connections > 0) {
    console.warn(`Forcing close with ${connections} connections still open`);
  }

  // 3. Close database pool
  await pool.end();
  console.log("DB pool closed");

  // 4. Flush observability (Sentry, OTel, etc.)
  await Sentry.flush(2000);
  console.log("Observability flushed");

  // 5. Clean exit
  process.exit(0);
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));   // Ctrl+C in dev

// Safety net: force exit after 35s if graceful shutdown hangs
process.on("SIGTERM", () => setTimeout(() => process.exit(1), 35_000).unref());
```

### Kubernetes Configuration
```yaml
# deployment.yaml
spec:
  template:
    spec:
      terminationGracePeriodSeconds: 60  # k8s waits this long before SIGKILL
      containers:
        - name: app
          lifecycle:
            preStop:
              exec:
                command: ["sleep", "5"]  # wait for load balancer to deregister pod
```

The `preStop` sleep is critical: Kubernetes sends SIGTERM simultaneously with removing the pod from the load balancer's endpoint list, but the load balancer update propagates with latency. The sleep ensures no new requests arrive during the drain window.

### Next.js / Vercel
Vercel handles graceful shutdown automatically for serverless deployments — each request is isolated. For self-hosted Next.js:
```typescript
// server.ts (custom server)
const server = app.listen(3000);
process.on("SIGTERM", async () => {
  server.close();
  // Next.js doesn't expose internal connection draining — rely on the HTTP server close
  await waitForConnections();
  process.exit(0);
});
```

## Key Rules
- Listen for `SIGTERM` — that's what Kubernetes, Docker, and most orchestrators send first
- Stop accepting new connections before draining — `server.close()` prevents new accepts but doesn't disconnect existing
- Set a drain deadline (30s) and exit anyway if connections don't drain — a hung request shouldn't block the shutdown forever
- Always flush observability buffers (Sentry, OpenTelemetry) during shutdown — otherwise the last batch of errors/traces from before a crash is lost
- Add a `preStop` sleep of 5-10s in Kubernetes — load balancer deregistration is not instantaneous
- Set `terminationGracePeriodSeconds` higher than your drain timeout — Kubernetes SIGKILL comes at this limit
- Register the SIGKILL force-exit as a safety net via `setTimeout(..., drainTimeout + 5000).unref()` — prevents zombie processes if shutdown logic hangs
