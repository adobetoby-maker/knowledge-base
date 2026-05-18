# Principle: Health Check Design

## Overview
Health checks are how orchestrators (Kubernetes, ECS, load balancers) know whether to send traffic to a service instance. Badly designed health checks cause two failure modes: false positives (service reported healthy but cannot actually serve requests, so users get errors) and false negatives (service killed by the orchestrator when it was actually fine, causing unnecessary restarts). Getting health checks right is a prerequisite for reliable deployments.

## Two Distinct Checks

### Liveness: "Is the process alive?"
The liveness probe answers: "Should Kubernetes restart this container?" It should only fail when the process is stuck in an unrecoverable state (deadlock, infinite loop, OOM). A liveness failure triggers a container restart.

```typescript
// /health — minimal, fast, no external dependencies
app.get("/health", (req, res) => {
  res.json({ status: "ok", uptime: process.uptime() });
});
```

The liveness endpoint must never check external dependencies. If it calls the database and the database is down, every pod gets restarted in a cascade — which is the last thing you want during a DB outage.

### Readiness: "Can this instance serve traffic?"
The readiness probe answers: "Should the load balancer send requests to this instance?" It should verify that all required external dependencies are reachable. A readiness failure removes the instance from the load balancer rotation (no restart, just no traffic).

```typescript
// /ready — checks dependencies
app.get("/ready", async (req, res) => {
  const checks: Record<string, "ok" | "fail"> = {};
  
  // Database
  try {
    await db.raw("SELECT 1");
    checks.database = "ok";
  } catch {
    checks.database = "fail";
  }

  // Cache
  try {
    await redis.ping();
    checks.cache = "ok";
  } catch {
    checks.cache = "fail";
  }

  // Required config loaded
  checks.config = process.env.REQUIRED_VAR ? "ok" : "fail";

  const healthy = Object.values(checks).every(v => v === "ok");
  res.status(healthy ? 200 : 503).json({ status: healthy ? "ready" : "not_ready", checks });
});
```

## Kubernetes Configuration

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 10    # give app time to start
  periodSeconds: 10
  failureThreshold: 3        # 3 consecutive failures before restart

readinessProbe:
  httpGet:
    path: /ready
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 2        # remove from rotation faster
```

## Startup Probe (Kubernetes 1.16+)
For slow-starting applications, a startup probe prevents the liveness probe from killing the process during initialization:
```yaml
startupProbe:
  httpGet:
    path: /health
    port: 3000
  failureThreshold: 30       # up to 5 minutes to start (30 × 10s)
  periodSeconds: 10
```

Once the startup probe succeeds once, liveness and readiness take over.

## What Goes in Readiness Checks
- Database connection (run a lightweight query, not a SELECT *)
- Cache connection (Redis PING)
- Required environment variables present
- Any config that must be loaded from external source before serving

## What Never Goes in Health Checks
- Business logic (checking pending order counts, running analytics)
- Slow operations (anything > 500ms — health checks run every few seconds)
- Operations with side effects (don't write to DB in a health check)
- Checks for non-critical dependencies (degraded-but-functional is "ready")

## Differentiate "Degraded" from "Down"
If the search service is down but the core API still functions, `/ready` should return 200 with `{ search: "degraded" }`. Only return 503 when the instance genuinely cannot serve its primary purpose.

## Key Rules
- `/health` = liveness = no external calls = fast
- `/ready` = readiness = checks all required dependencies
- Liveness failure → restart; readiness failure → remove from rotation
- Health checks must respond in < 500ms; add circuit breaker if DB check is slow
- Never put business logic in health checks
- Log when readiness changes state (ok → not_ready and back)
