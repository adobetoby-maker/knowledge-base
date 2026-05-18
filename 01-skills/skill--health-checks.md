# Application Health Check Endpoints

## Why Two Endpoints, Not One

Kubernetes (and most orchestrators) distinguishes between two concepts:

- **Liveness** (`/live`): "Is this process alive and not deadlocked?" If this fails, the orchestrator kills and restarts the container. It should be lightweight — no external dependency checks.
- **Readiness** (`/ready`): "Is this instance ready to receive traffic?" If this fails, the load balancer removes the instance from rotation but does not restart it. Check DB connectivity, required env vars, cache warmup here.

A single `/health` endpoint collapses these. A slow DB check on the liveness probe causes unnecessary pod restarts. A bare 200 on the readiness probe sends traffic to instances that can't serve it.

## `/live` Implementation

Liveness must be cheap — the probe fires every 10–30 seconds per instance. Return 200 with a minimal payload. The only failure case should be process-level corruption:

```ts
app.get('/live', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});
```

Do not check the database here. A DB outage should not cause restarts; it should cause traffic removal.

## `/ready` Implementation

Readiness checks actual dependencies. Fail fast — set tight timeouts per check so the probe doesn't hang:

```ts
app.get('/ready', async (req, res) => {
  const checks: Record<string, { ok: boolean; latencyMs?: number; error?: string }> = {};
  const start = Date.now();

  // Database check
  try {
    await db.raw('SELECT 1').timeout(500);
    checks.database = { ok: true, latencyMs: Date.now() - start };
  } catch (e) {
    checks.database = { ok: false, error: e.message };
  }

  // External dependency (optional — only if app is non-functional without it)
  try {
    const t = Date.now();
    await stripe.balance.retrieve(); // Stripe ping
    checks.stripe = { ok: true, latencyMs: Date.now() - t };
  } catch (e) {
    checks.stripe = { ok: false, error: 'stripe unreachable' };
  }

  const healthy = Object.values(checks).every(c => c.ok);
  res.status(healthy ? 200 : 503).json({ status: healthy ? 'ready' : 'unavailable', checks });
});
```

Return 503 (not 500) when unhealthy — load balancers treat 5xx as a routing signal differently depending on the code.

## What to Check in `/ready`

Check only what makes the instance unable to serve requests:
- **Database connectivity**: a single lightweight query (`SELECT 1`) — not a full table scan.
- **Required env vars**: if `STRIPE_SECRET_KEY` is missing, the app can't process payments. Fail loudly.
- **Critical external services**: only those required for every request. A PDF generation service used by 5% of endpoints should degrade gracefully, not block readiness.

Do NOT check things that are acceptable to degrade:
- Email sending (queue it)
- Analytics services
- Non-critical third-party APIs

## Response Time SLA

If the readiness check itself is slow, the orchestrator may mark the instance unhealthy due to timeout. Keep the total response time under 2 seconds. Each individual check should have a 500ms timeout. Checks run in parallel:

```ts
const [dbResult, redisResult] = await Promise.allSettled([
  checkDb(),
  checkRedis(),
]);
```

`Promise.allSettled` — not `Promise.all` — ensures all checks complete even when one fails. With `Promise.all`, a single check failure short-circuits and hides the status of the others.

## Protecting Health Endpoints

Health endpoints can leak environment information (DB host, service names, error messages). Options:
- Return a simplified response in production: `{ status: "ok" }` publicly, detailed status only from internal network.
- Gate detailed output behind an internal header checked against a static secret: `X-Health-Token: <secret>`.
- For Kubernetes: configure `httpHeaders` in the probe spec to inject the header automatically — no external exposure.

## `/health` for Simple Cases

If not running on Kubernetes and a single endpoint is acceptable, use `/health`:

```ts
app.get('/health', async (req, res) => {
  // same as /ready
});
```

Return `{ status: "ok" | "degraded" | "down", version: process.env.npm_package_version }`. Including the version makes it trivially easy to confirm which code is running in an environment.

## Key Rules

- Use `/live` (no external checks) and `/ready` (full dependency checks) separately for Kubernetes.
- `/live` returning 503 triggers a **restart** — never put DB checks there.
- Each dependency check must have a **hard timeout** (500ms) to prevent probe hangs.
- Run checks **in parallel** with `Promise.allSettled`, not sequentially or with `Promise.all`.
- Return **503** (not 500) when unhealthy — different routing semantics.
- **Redact error details** from public-facing health endpoints or gate with an internal header.
- Include `version` in the response to verify **which deploy is running**.
