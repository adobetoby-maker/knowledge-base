# Principle: Preemptive Monitoring

## Overview
Reactive monitoring — alerting when a threshold is crossed — catches problems after they've become incidents. Preemptive monitoring catches them while they're still trends. The difference: an error rate above 1% is an incident; an error rate rising from 0.1% to 0.3% over 20 minutes is a trend that, if caught, enables intervention before users are affected. The goal of monitoring is to detect problems before users do. If "users reported an outage," monitoring failed.

## Implementation

### Leading vs Lagging Indicators
```
Lagging (you're already in trouble):     Leading (you might be about to be):
- Error rate > 1%                        - Error rate rising (trending)
- P99 latency > 5s                       - P99 latency increasing each minute
- DB CPU at 95%                          - DB CPU at 60% and growing
- Disk usage > 90%                       - Disk usage growing 1GB/day
- Payment failure rate > 5%             - Auth failure rate above baseline
```

Always alert on both, but leading indicators give you time to act.

### Rate-of-Change Alerts (Prometheus Example)
```yaml
# Alert on error rate trend, not just absolute threshold
- alert: ErrorRateRising
  expr: |
    rate(http_requests_total{status=~"5.."}[5m])
    / rate(http_requests_total[5m])
    > 0.01   # absolute threshold
  OR
    deriv(rate(http_requests_total{status=~"5.."}[10m])[30m:5m]) > 0.001  # rising trend
  for: 3m
  labels:
    severity: warning
  annotations:
    summary: "Error rate is rising — currently {{ $value | humanizePercentage }}"
```

### Queue Depth Monitoring
A growing queue signals that consumers can't keep up. Alert before it becomes a backlog crisis:

```ts
// Prometheus-style metric collection
const queueDepthGauge = new Gauge({
  name: 'job_queue_depth',
  help: 'Number of jobs waiting to be processed',
  labelNames: ['queue_name'],
});

// Report queue depth every 30 seconds
setInterval(async () => {
  for (const queueName of ['emails', 'webhooks', 'exports']) {
    const depth = await getQueueDepth(queueName);
    queueDepthGauge.set({ queue_name: queueName }, depth);
  }
}, 30_000);
```

```yaml
# Alert when queue depth is growing, not just when it's large
- alert: QueueDepthGrowing
  expr: deriv(job_queue_depth[10m]) > 10  # growing by 10 items/minute
  for: 5m
  annotations:
    summary: "Queue {{ $labels.queue_name }} is accumulating — {{ $value }} items/min growth rate"
```

### Synthetic Monitoring
Run test transactions that exercise the full stack on a schedule. This catches "the monitoring alerts are silent but nothing actually works" scenarios:

```ts
// Runs every minute from an external location
async function syntheticHealthCheck() {
  const start = Date.now();
  const results = {
    timestamp: new Date().toISOString(),
    checks: {} as Record<string, { success: boolean; latencyMs: number; error?: string }>,
  };

  // Check critical paths
  for (const [name, check] of [
    ['api_health', () => fetch(`${API_URL}/health`)],
    ['db_query', () => fetch(`${API_URL}/health/db`)],
    ['stripe_webhook', () => fetch(`${API_URL}/health/stripe`)],
    ['email_sending', () => fetch(`${API_URL}/health/email`)],
  ]) {
    const checkStart = Date.now();
    try {
      const res = await (check as () => Promise<Response>)();
      results.checks[name] = {
        success: res.ok,
        latencyMs: Date.now() - checkStart,
      };
    } catch (err) {
      results.checks[name] = {
        success: false,
        latencyMs: Date.now() - checkStart,
        error: (err as Error).message,
      };
    }
  }

  // Alert if any check failed
  const failed = Object.entries(results.checks).filter(([, r]) => !r.success);
  if (failed.length > 0) {
    await alertOncall(`Synthetic check failed: ${failed.map(([n]) => n).join(', ')}`);
  }

  return results;
}
```

### Anomaly Detection for Gradual Degradation
Gradual issues (memory leak, slow index degradation, creeping response times) don't cross absolute thresholds for days:

```ts
// Track rolling baseline and alert on deviation
const METRICS_WINDOW = 7 * 24 * 60; // 7 days in minutes

async function detectAnomalies(metricName: string, currentValue: number) {
  const baseline = await getPercentile(metricName, 95, METRICS_WINDOW); // p95 over last 7 days
  const stddev = await getStddev(metricName, METRICS_WINDOW);

  // Alert if current value is more than 3 standard deviations above baseline
  if (currentValue > baseline + 3 * stddev) {
    await alertOncall(`Anomaly detected: ${metricName} is ${currentValue.toFixed(2)} (baseline: ${baseline.toFixed(2)}, threshold: ${(baseline + 3 * stddev).toFixed(2)})`);
  }
}
```

### The "Users Reported" Failure Mode
```
Incident timeline comparison:
"Users reported" model:     User affected → user reports → ticket created → engineer paged = 30+ minutes
Proactive model:            Trend detected → alert fires → engineer investigates = 2-5 minutes before user impact
```

When "users reported" appears in a postmortem, the monitoring gap must be addressed, not just the incident.

## Key Rules
- Alert on trends (rate of change), not just thresholds — trends give you lead time.
- Synthetic monitoring from an external location is mandatory for detecting complete outages — internal metrics won't alert if the monitoring server itself is down.
- Queue depth monitoring is as important as error rate monitoring — a silent backlog is an incident waiting to happen.
- "Users reported an outage" in a postmortem is a monitoring failure that must be tracked separately.
- P99 latency is a better SLI than average latency — average hides tail experiences that affect real users.
- Alert fatigue kills monitoring programs — tune thresholds ruthlessly and remove alerts that nobody acts on.
- Mean Time to Detect (MTTD) is as important a metric as Mean Time to Resolve (MTTR) — reduce MTTD to reduce total incident impact.
