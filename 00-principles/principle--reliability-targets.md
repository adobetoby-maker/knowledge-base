# Principle: Reliability Targets (SLI / SLO / SLA)

## Overview
Reliability without targets is opinion. With SLOs, it becomes an engineering constraint that shapes architecture decisions, on-call responses, and deployment risk tolerance. The error budget is the key insight: you have a finite amount of unreliability you're allowed, and you should spend it deliberately on risky deployments — not waste it on preventable failures.

## Implementation / Key Points

### Definitions
```
SLI (Service Level Indicator) = What you measure
  "Percentage of HTTP requests that returned 2xx or 3xx in the last 30 days"
  "P99 latency of API endpoints over the last 7 days"

SLO (Service Level Objective) = Internal target
  "SLI ≥ 99.9% availability"
  "P99 latency ≤ 500ms"

SLA (Service Level Agreement) = External commitment with consequences
  "99.9% availability; customer gets 10% credit if we miss it"

Error Budget = 100% - SLO = allowed unreliability
  99.9% SLO → 0.1% budget = 43.8 minutes downtime per month allowed
  99.5% SLO → 0.5% budget = 3.6 hours downtime per month allowed
```

### Common SLIs to Track
```ts
// Availability SLI
const availabilitySLI = successfulRequests / totalRequests * 100;

// Latency SLI (what % of requests are fast enough?)
const latencySLI = requestsUnder500ms / totalRequests * 100;

// Error rate SLI
const errorRateSLI = (1 - (5xxErrors / totalRequests)) * 100;
```

### Error Budget Burn Rate
```
Monthly budget: 0.1% = 43.8 minutes

If you've used 30 minutes in the first 10 days:
  Burn rate = (30min / 43.8min) / (10 / 30 days) = 68.5% / 33.3% = 2.06x normal burn rate
  At this rate, budget runs out in ~20 days → alert, freeze risky deployments
```

### Alert Thresholds
```yaml
# Alert when 2% of monthly budget is consumed in a 1-hour window
# (fast burn = production is on fire)
- alert: FastBurnRate
  condition: burn_rate_1h > 14.4   # 1440 minutes/month * 0.001 * 14.4 = exhausted in 1h
  severity: critical
  action: page on-call

# Alert when 5% of monthly budget is consumed in a 6-hour window
# (slow burn = trend will exhaust budget)
- alert: SlowBurnRate
  condition: burn_rate_6h > 6
  severity: warning
  action: ticket to SRE team
```

### Spending the Error Budget Deliberately
```
Error budget is not a floor to avoid — it's a resource to spend wisely.
  
  OK to spend budget on:
    - Risky but high-value deployments (major feature launches)
    - Infrastructure migrations
    - Planned maintenance windows
    
  NOT OK to spend budget on:
    - Preventable bugs shipped without testing
    - Repeated incidents from the same root cause
    - Configuration errors caught by staging but deployed anyway

Rule: if budget is > 50% remaining, proceed with risky work.
      If budget is < 20% remaining, freeze risky deployments.
      If budget is exhausted, stop all changes except reliability fixes.
```

### Setting Realistic SLOs
```
Start with measurement, not aspiration:
  - Measure actual availability for 30 days
  - SLO = actual performance - 10% buffer
  
Example: measured 99.92% → set SLO at 99.9%
Never set SLO above demonstrated performance — you'll violate it on day 1.
```

## Key Rules
- SLI = measure it. SLO = target it internally. SLA = commit to it externally.
- Error budget = 100% - SLO; it is a resource, not a shame counter.
- Alert at 2% fast burn and 5% slow burn, not at SLO violation (that's too late).
- When budget runs low, freeze risky deployments until the month resets.
- Spend error budget deliberately on valuable risky work, not on preventable failures.
- Set SLO at demonstrated performance minus a small buffer — not at an aspiration.
- Review error budget consumption weekly; blameless postmortem for every SLO violation.
