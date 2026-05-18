# Skill: Chaos Engineering Basics

## Overview
Chaos engineering verifies that your system degrades gracefully when components fail — it uncovers hidden dependencies, single points of failure, and missing circuit breakers before an unplanned outage does. The discipline: run experiments in staging first with clear success/failure criteria, automate what you've validated, and never run untested chaos in production. "Graceful degradation" means users see a fallback, not a crash.

## Implementation

### 1. Manual experiments to run first
```bash
# Experiment 1: Kill one service instance — does load balancer reroute?
# Expected: other instances absorb traffic, p95 latency stays under 2s
kubectl scale deployment order-service --replicas=0 -n staging

# Verify in another terminal
watch -n1 'curl -s -o /dev/null -w "%{http_code}" https://staging.example.com/api/health'
# Should stay 200 — other services are healthy

# Restore
kubectl scale deployment order-service --replicas=3 -n staging
```

```bash
# Experiment 2: Add 200ms latency to DB — does app timeout gracefully?
# Using tc (traffic control) on the DB host, or toxiproxy for local testing
toxiproxy-cli toxic add --type latency --attribute latency=200 postgres-proxy

# Run load test while toxic is active
k6 run load-tests/purchase-flow.js

# Expected: p95 increases proportionally, circuit breakers open, fallbacks serve cached data
# Failure signal: app hangs, no timeouts, connection pool exhausted

toxiproxy-cli toxic remove postgres-proxy
```

### 2. toxiproxy for local chaos testing
```yaml
# docker-compose.yml — proxy all external deps through toxiproxy
services:
  toxiproxy:
    image: ghcr.io/shopify/toxiproxy
    ports:
      - "8474:8474"   # management API
      - "5433:5433"   # proxied postgres
      - "6380:6380"   # proxied redis

  app:
    environment:
      DATABASE_URL: "postgres://user:pass@toxiproxy:5433/mydb"  # go through proxy
      REDIS_URL: "redis://toxiproxy:6380"
```

```ts
// scripts/chaos/inject-latency.ts
import { ToxiproxyClient } from 'toxiproxy-node-client';

const client = new ToxiproxyClient('http://localhost:8474');

// Setup proxies (run once)
async function setup() {
  await client.createProxy({ name: 'postgres', listen: '0.0.0.0:5433', upstream: 'postgres:5432' });
  await client.createProxy({ name: 'redis', listen: '0.0.0.0:6380', upstream: 'redis:6379' });
}

// Experiment: DB latency
async function injectDBLatency(latencyMs: number) {
  const proxy = await client.getProxy('postgres');
  await proxy.addToxic({ type: 'latency', name: 'db_latency', attributes: { latency: latencyMs } });
  console.log(`Injected ${latencyMs}ms DB latency`);
  return () => proxy.removeToxic('db_latency');  // cleanup fn
}

// Experiment: Return 503 from external API
async function injectAPIDowntime() {
  const proxy = await client.getProxy('external-api');
  await proxy.addToxic({
    type: 'reset_peer',  // closes connection — simulates service unreachable
    name: 'api_down',
    attributes: {},
  });
  return () => proxy.removeToxic('api_down');
}
```

### 3. Automated chaos with chaos-mesh (Kubernetes staging)
```yaml
# chaos/db-latency.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: db-latency-test
  namespace: staging
spec:
  action: delay
  mode: one             # target one pod at a time
  selector:
    namespaces:
      - staging
    labelSelectors:
      'app': 'postgres'
  delay:
    latency: '200ms'
    jitter: '50ms'      # variability makes it more realistic
  duration: '5m'        # auto-stops after 5 minutes
```

```yaml
# chaos/service-kill.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: order-service-kill
  namespace: staging
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces: [staging]
    labelSelectors:
      'app': 'order-service'
  scheduler:
    cron: '0 */6 * * *'  # kill one pod every 6 hours in staging
```

### 4. Define success criteria BEFORE running
```ts
// chaos/experiments/db-latency.ts
const experiment = {
  name: 'DB 200ms latency injection',
  hypothesis: 'System returns cached responses when DB is slow; error rate stays under 1%',
  
  // Measure these during the experiment
  steadyState: {
    errorRate: 0.001,     // < 0.1% baseline
    p95Latency: 500,      // ms baseline
  },
  
  // Success: system degrades proportionally but stays functional
  successCriteria: {
    errorRate: 0.01,      // < 1% during chaos
    p95Latency: 3000,     // < 3s (slower, but not broken)
    featureAvailability: ['cart', 'checkout'],  // these must still work
    fallbackActivated: true,  // circuit breaker or cache must engage
  },
  
  // What to watch for
  rollbackTrigger: {
    errorRate: 0.1,       // > 10% = stop immediately
  },
};
```

### 5. Chaos runbook template
```markdown
## Chaos Experiment: [Name]

**Hypothesis:** When [failure condition], [expected behavior]
**Blast radius:** [staging / prod, which services affected]
**Duration:** [how long chaos runs]
**Rollback:** [exact command to stop]

### Pre-experiment checklist
- [ ] Alerting is muted for expected alarms
- [ ] On-call engineer is aware and standing by
- [ ] Rollback command tested (not just written down)
- [ ] Monitoring dashboards open

### Metrics to watch during experiment
- Error rate (threshold: < 1%)
- p95 latency (threshold: < 3s)
- Circuit breaker state

### Stop immediately if
- Error rate > 10%
- Any data corruption observed
- Customer-impacting behavior in prod
```

## Key Rules
- **Define success criteria before injecting chaos** — deciding "did it degrade gracefully?" after seeing results is confirmation bias.
- **Always test in staging before automating** — first run is exploratory; you're learning what breaks, not validating what holds.
- **Have a rollback command written down and tested** before starting — not "I'll figure it out if needed."
- Start with read-path failures (cache miss, read replica down) before write-path failures (DB write unavailable).
- Chaos must be bounded: set `duration` so experiments self-terminate; don't rely on manual cleanup.
- Never run untested chaos in production — only automate experiments that have passed in staging at least 3 times.
- The goal is graceful degradation, not zero impact: users seeing a "service temporarily limited" banner is success; users seeing a crash page or data corruption is failure.
